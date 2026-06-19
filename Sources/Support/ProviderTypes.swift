import Foundation
import WebKit

struct ProviderUsage: Sendable, Codable {
    var sessionPct: Double?
    var weeklyPct: Double?
    var sessionResetAt: Date?
    var weeklyResetAt: Date?
    var planName: String?
    var quotaLanes: [ProviderQuotaLane]?
    var fetchedAt: Date = Date()

    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 600 }
    var sessionAtLimit: Bool { (sessionPct ?? 0) >= 99.99 }
    var weeklyAtLimit: Bool { (weeklyPct ?? 0) >= 99.99 }
    var atLimit: Bool { sessionAtLimit || weeklyAtLimit }

    var glancePct: Double? {
        if let lanes = quotaLanes, !lanes.isEmpty {
            return lanes.map(\.pct).max()
        }
        let values = [sessionPct, weeklyPct].compactMap { $0 }
        return values.max()
    }
}

struct ProviderQuotaLane: Sendable, Codable, Identifiable {
    var id: String
    var label: String
    var group: String?
    var pct: Double
    var resetAt: Date?
    var resetText: String?
}

enum AuthState: String, Codable {
    case signedOut, signedIn, expired
}

enum FetchResult {
    case success(ProviderUsage)
    case authExpired
    case failure
}

let safariUserAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"

@MainActor
enum ProviderDataStores {
    static func store(for id: AIProvider) -> WKWebsiteDataStore {
        if id == .claude { return .default() }
        let storeID: AIProvider = id == .antigravity ? .gemini : id
        let key = "providerStoreUUID.\(storeID.rawValue)"
        let ud = UserDefaults.standard
        let uuid: UUID
        if let s = ud.string(forKey: key), let u = UUID(uuidString: s) {
            uuid = u
        } else {
            let u = UUID()
            ud.set(u.uuidString, forKey: key)
            uuid = u
        }
        return WKWebsiteDataStore(forIdentifier: uuid)
    }
}

@MainActor
extension WKWebsiteDataStore {
    func cookies(matching domain: String) async -> [HTTPCookie] {
        await withCheckedContinuation { cont in
            httpCookieStore.getAllCookies { cookies in
                cont.resume(returning: cookies.filter { $0.domain.contains(domain) })
            }
        }
    }

    func hasCookie(domain: String, where predicate: @escaping (HTTPCookie) -> Bool) async -> Bool {
        let all = await cookies(matching: domain)
        return all.contains { predicate($0) && !$0.value.isEmpty }
    }

    func clearCookies(domain: String) async {
        let all = await cookies(matching: domain)
        for c in all {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                httpCookieStore.delete(c) { cont.resume() }
            }
        }
    }

    func wipeAllData() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            removeData(ofTypes: types, modifiedSince: .distantPast) { cont.resume() }
        }
    }
}

func providerNum(_ any: Any?) -> Double? {
    if let n = any as? NSNumber { return n.doubleValue }
    if let s = any as? String { return Double(s) }
    return nil
}

func providerDate(_ any: Any?) -> Date? {
    if let s = any as? String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: s) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: s)
    }
    if let n = providerNum(any) {
        return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
    }
    return nil
}

func providerPct(_ any: Any?) -> Double? {
    guard let v = providerNum(any) else { return nil }
    if v <= 1.0 && v != v.rounded() { return v * 100 }
    return v
}

enum ResetTimeParser {
    static func parseSessionReset(_ text: String, relativeTo: Date) -> Date? {
        var total: TimeInterval = 0

        let dRegex = try? NSRegularExpression(pattern: #"(\d+)\s*d"#, options: .caseInsensitive)
        let hRegex = try? NSRegularExpression(pattern: #"(\d+)\s*h"#, options: .caseInsensitive)
        let mRegex = try? NSRegularExpression(pattern: #"(\d+)\s*m"#, options: .caseInsensitive)
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)

        if let m = dRegex?.firstMatch(in: text, range: range), m.numberOfRanges >= 2 {
            if let v = Int(ns.substring(with: m.range(at: 1))) { total += TimeInterval(v * 86_400) }
        }
        if let m = hRegex?.firstMatch(in: text, range: range), m.numberOfRanges >= 2 {
            if let v = Int(ns.substring(with: m.range(at: 1))) { total += TimeInterval(v * 3600) }
        }
        if let m = mRegex?.firstMatch(in: text, range: range), m.numberOfRanges >= 2 {
            if let v = Int(ns.substring(with: m.range(at: 1))) { total += TimeInterval(v * 60) }
        }
        return total > 0 ? relativeTo.addingTimeInterval(total) : nil
    }

    static func parseWeeklyReset(_ text: String, relativeTo: Date) -> Date? {
        let pattern = #"(Mon|Tue|Wed|Thu|Fri|Sat|Sun)[a-z]*\s+(?:at\s+)?(\d{1,2}):(\d{2})\s*(AM|PM)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= 5 else { return nil }

        let dayStr = ns.substring(with: m.range(at: 1)).lowercased()
        let hour = Int(ns.substring(with: m.range(at: 2))) ?? 0
        let mins = Int(ns.substring(with: m.range(at: 3))) ?? 0
        let ampm = ns.substring(with: m.range(at: 4)).lowercased()

        let dayMap = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]
        guard let weekday = dayMap[String(dayStr.prefix(3))] else { return nil }

        var hour24 = hour
        if ampm == "pm" && hour < 12 { hour24 += 12 }
        if ampm == "am" && hour == 12 { hour24 = 0 }

        var comp = DateComponents()
        comp.weekday = weekday
        comp.hour = hour24
        comp.minute = mins
        comp.second = 0
        return Calendar.current.nextDate(after: relativeTo, matching: comp, matchingPolicy: .nextTime)
    }
}
