import Foundation
import WebKit

/// Lets the user authenticate a provider by pasting its own session cookie, for when the
/// in-app login is blocked (Google SSO refuses embedded WebViews). The value is written
/// straight into that provider's WebKit cookie store and never leaves the machine — usage
/// requests go directly from here to the provider, same as a normal sign-in.
@MainActor
enum SessionCookieInjector {
    /// Accepts the raw cookie value or a "name=value" paste; trims quotes/space.
    @discardableResult
    static func set(_ raw: String, for provider: AIProvider) async -> Bool {
        guard let spec = provider.sessionCookie else { return false }

        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = value.range(of: "\(spec.name)=") {
            value = String(value[range.upperBound...])
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'; "))
        guard !value.isEmpty else { return false }

        let store = ProviderDataStores.store(for: provider)
        let props: [HTTPCookiePropertyKey: Any] = [
            .domain: spec.domain,
            .path: "/",
            .name: spec.name,
            .value: value,
            .secure: true,
            .expires: Date().addingTimeInterval(365 * 24 * 3600),
        ]
        guard let cookie = HTTPCookie(properties: props) else { return false }
        await store.httpCookieStore.setCookie(cookie)
        return true
    }
}
