import Foundation
import WebKit

// Cursor usage via the dashboard JSON API (unofficial):
//   GET /api/usage-summary  -> billing cycle, plan %, on-demand spend
// Auth: WorkosCursorSessionToken cookie from cursor.com login.
@MainActor
final class CursorQuotaEngine {
    let provider = AIProvider.cursor
    private let dataStore = ProviderDataStores.store(for: .cursor)
    private lazy var webFetcher = WebViewFetcher(dataStore: dataStore)

    private static let sessionCookie = "WorkosCursorSessionToken"
    private static let usageSummaryURL = URL(string: "https://cursor.com/api/usage-summary")!

    // MARK: - Auth

    func checkAuth() async -> AuthState {
        let signedIn = await dataStore.hasCookie(domain: "cursor.com") {
            $0.name == Self.sessionCookie
        }
        return signedIn ? .signedIn : .signedOut
    }

    func presentLogin(onComplete: @escaping @MainActor () -> Void) {
        presentInAppLogin(onComplete: onComplete)
    }

    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void) {
        WebAuthController.show(WebAuthController.Config(
            providerID: .cursor,
            title: "Sign in to Cursor",
            startURL: URL(string: "https://cursor.com/login")!,
            dataStore: dataStore,
            loginCheck: { _, url in
                url.host?.contains("cursor.com") == true && !url.path.contains("login")
            },
            authCookieCheck: { ds in
                await ds.hasCookie(domain: "cursor.com") {
                    $0.name == "WorkosCursorSessionToken" && !$0.value.isEmpty
                }
            }
        ), onComplete: onComplete)
    }

    func signOut() async {
        webFetcher.release()
        await dataStore.clearCookies(domain: "cursor.com")
    }

    func releaseIdleResources() {
        webFetcher.release()
    }

    // MARK: - Fetch

    func fetchUsage() async -> FetchResult {
        let cookies = await dataStore.cookies(matching: "cursor.com")
        guard cookies.contains(where: { $0.name == Self.sessionCookie && !$0.value.isEmpty }) else {
            return .authExpired
        }

        switch await fetchViaURLSession(cookies: cookies) {
        case .success(let u): return .success(u)
        case .authExpired:    return .authExpired
        case .failure:        return await fetchViaWebView()
        }
    }

    private func fetchViaURLSession(cookies: [HTTPCookie]) async -> FetchResult {
        do {
            let (json, status) = try await CookieAPIFetcher.getJSON(
                url: Self.usageSummaryURL,
                cookies: cookies,
                referer: "https://cursor.com/dashboard/usage"
            )
            if status == 401 { return .authExpired }
            if let obj = json as? [String: Any], obj["error"] as? String == "not_authenticated" {
                return .authExpired
            }
            guard status == 200, let obj = json as? [String: Any] else { return .failure }
            guard let usage = Self.parseUsage(obj) else { return .failure }
            return .success(usage)
        } catch {
            return .failure
        }
    }

    private func fetchViaWebView() async -> FetchResult {
        let script = """
        try {
            const r = await fetch('/api/usage-summary', {
                credentials: 'include',
                headers: { 'Accept': 'application/json' }
            });
            if (r.status === 401 || r.status === 403) return JSON.stringify({ error: 'auth' });
            if (!r.ok) return JSON.stringify({ error: 'http_' + r.status });
            return JSON.stringify({ data: await r.json() });
        } catch (e) {
            return JSON.stringify({ error: String(e) });
        }
        """
        guard let raw = await webFetcher.run(
                pageURL: URL(string: "https://cursor.com/dashboard/usage")!,
                script: script),
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            webFetcher.invalidatePage()
            return .failure
        }
        if (obj["error"] as? String) == "auth" { return .authExpired }
        guard let payload = obj["data"] as? [String: Any],
              let usage = Self.parseUsage(payload) else {
            webFetcher.invalidatePage()
            return .failure
        }
        return .success(usage)
    }

    private static func hasSessionCookie(in store: WKWebsiteDataStore) async -> Bool {
        await withCheckedContinuation { cont in
            store.httpCookieStore.getAllCookies { cookies in
                let ok = cookies.contains {
                    $0.domain.contains("cursor.com")
                        && $0.name == sessionCookie
                        && !$0.value.isEmpty
                }
                cont.resume(returning: ok)
            }
        }
    }

    static func parseUsage(_ obj: [String: Any]) -> ProviderUsage? {
        var u = ProviderUsage(fetchedAt: Date())

        if let membership = obj["membershipType"] as? String, !membership.isEmpty {
            u.planName = membership.capitalized
        }

        if let cycleEnd = providerDate(obj["billingCycleEnd"]) {
            u.sessionResetAt = cycleEnd
            u.weeklyResetAt = cycleEnd
        }

        if obj["isUnlimited"] as? Bool == true {
            u.sessionPct = 0
            u.weeklyPct = 0
            return u
        }

        if let individual = obj["individualUsage"] as? [String: Any],
           let plan = individual["plan"] as? [String: Any],
           plan["enabled"] as? Bool != false {
            u.sessionPct = planPercent(plan, key: "totalPercentUsed", usedKey: "used", limitKey: "limit")
            u.weeklyPct = planPercent(plan, key: "apiPercentUsed", usedKey: "used", limitKey: "limit")
                ?? planPercent(plan, key: "autoPercentUsed", usedKey: "used", limitKey: "limit")

            if let breakdown = plan["breakdown"] as? [String: Any],
               let used = providerNum(plan["used"]),
               let included = providerNum(breakdown["included"]),
               let total = providerNum(breakdown["total"]), total > 0 {
                u.planName = [u.planName, String(format: "%.0f/%.0f", used, total)]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                _ = included
            }
        }

        if let individual = obj["individualUsage"] as? [String: Any],
           let onDemand = individual["onDemand"] as? [String: Any],
           onDemand["enabled"] as? Bool == true {
            let usedCents = providerNum(onDemand["used"]) ?? 0
            if usedCents > 0 {
                let spent = String(format: "$%.2f", usedCents / 100.0)
                var lane = ProviderQuotaLane(
                    id: "on-demand",
                    label: "On-demand (\(spent))",
                    group: nil,
                    pct: 0,
                    resetAt: u.weeklyResetAt,
                    resetText: nil
                )
                if let limitCents = providerNum(onDemand["limit"]), limitCents > 0 {
                    lane.pct = min(usedCents / limitCents * 100, 100)
                    lane.label = "On-demand"
                    lane.resetText = spent
                }
                u.quotaLanes = [lane]
            }
        }

        guard u.sessionPct != nil || u.weeklyPct != nil || u.quotaLanes != nil else { return nil }
        return u
    }

    private static func planPercent(
        _ plan: [String: Any],
        key: String,
        usedKey: String,
        limitKey: String
    ) -> Double? {
        if let pct = providerPct(plan[key]) { return pct }
        guard let used = providerNum(plan[usedKey]),
              let limit = providerNum(plan[limitKey]),
              limit > 0 else { return nil }
        return min(used / limit * 100, 100)
    }
}
