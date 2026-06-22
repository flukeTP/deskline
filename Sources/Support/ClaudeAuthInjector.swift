import Foundation
import WebKit

/// Lets the user authenticate Claude by pasting their own `sessionKey` cookie when
/// the in-app login is blocked (Google SSO refuses embedded WebViews). The value is
/// written straight into Claude's WebKit cookie store and never leaves the machine —
/// usage requests go directly from here to claude.ai, same as a normal sign-in.
@MainActor
enum ClaudeAuthInjector {
    /// Accepts either the raw cookie value or a "sessionKey=..." paste; trims quotes/space.
    static func setSessionKey(_ raw: String) async -> Bool {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = value.range(of: "sessionKey=") {
            value = String(value[range.upperBound...])
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'; "))
        guard !value.isEmpty else { return false }

        let store = ProviderDataStores.store(for: .claude)
        let props: [HTTPCookiePropertyKey: Any] = [
            .domain: ".claude.ai",
            .path: "/",
            .name: "sessionKey",
            .value: value,
            .secure: true,
            .expires: Date().addingTimeInterval(365 * 24 * 3600),
        ]
        guard let cookie = HTTPCookie(properties: props) else { return false }
        await store.httpCookieStore.setCookie(cookie)
        return true
    }
}
