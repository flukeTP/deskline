import Foundation
import WebKit

/// Lets the user authenticate a provider by pasting its own session cookie, for when the
/// in-app login is blocked (Google SSO refuses embedded WebViews). The value is written
/// straight into that provider's WebKit cookie store and never leaves the machine — usage
/// requests go directly from here to the provider, same as a normal sign-in.
@MainActor
enum SessionCookieInjector {
    /// Accepts the raw cookie value or a "name=value" paste. For large session JWTs that
    /// the browser splits across `name.0`, `name.1`, … (next-auth on ChatGPT), paste each
    /// chunk on its own line and they're written back as `name.0`, `name.1`, ….
    @discardableResult
    static func set(_ raw: String, for provider: AIProvider) async -> Bool {
        guard let spec = provider.sessionCookie else { return false }

        let chunks = raw
            .split(whereSeparator: { $0.isNewline })
            .map { cleanValue(String($0), name: spec.name) }
            .filter { !$0.isEmpty }
        guard !chunks.isEmpty else { return false }

        let store = ProviderDataStores.store(for: provider)
        if chunks.count == 1 {
            await setCookie(name: spec.name, value: chunks[0], domain: spec.domain, store: store)
        } else {
            for (i, value) in chunks.enumerated() {
                await setCookie(name: "\(spec.name).\(i)", value: value, domain: spec.domain, store: store)
            }
        }
        return true
    }

    /// Strip an optional "cookieName=" prefix and surrounding quotes/space from one line.
    private static func cleanValue(_ line: String, name: String) -> String {
        var v = line.trimmingCharacters(in: .whitespaces)
        if let eq = v.firstIndex(of: "="), v[..<eq].contains(name) {
            v = String(v[v.index(after: eq)...])
        }
        return v.trimmingCharacters(in: CharacterSet(charactersIn: "\"'; \t"))
    }

    private static func setCookie(name: String, value: String, domain: String, store: WKWebsiteDataStore) async {
        let props: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .path: "/",
            .name: name,
            .value: value,
            .secure: true,
            .expires: Date().addingTimeInterval(365 * 24 * 3600),
        ]
        guard let cookie = HTTPCookie(properties: props) else { return }
        await store.httpCookieStore.setCookie(cookie)
    }
}
