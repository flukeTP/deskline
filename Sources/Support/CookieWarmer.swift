import Foundation
import WebKit

/// Forces a `WKWebsiteDataStore` to load its persisted cookies from disk.
///
/// `WKWebsiteDataStore(forIdentifier:)` does not surface persisted cookies via
/// `httpCookieStore.getAllCookies` until the store has been "activated" — i.e. the
/// networking process attaches and reads `Cookies.binarycookies`. Adding a cookie-store
/// observer triggers that load. Without this, a freshly launched app reads zero cookies
/// and reports every provider signed-out even though the login is still valid on disk.
@MainActor
final class CookieWarmer {
    static let shared = CookieWarmer()

    private final class Activator: NSObject, WKHTTPCookieStoreObserver {
        func cookieStoreDidChange(_ cookieStore: WKHTTPCookieStore) {}
    }

    private var activators: [ObjectIdentifier: Activator] = [:]

    /// Activate a store (idempotent) and wait until its cookies have loaded, or `timeout`.
    func warmUp(_ store: WKWebsiteDataStore, timeout: TimeInterval = 2.0) async {
        let key = ObjectIdentifier(store)
        if activators[key] == nil {
            let activator = Activator()
            activators[key] = activator
            store.httpCookieStore.add(activator)
        }

        // The first getAllCookies after activation kicks the disk load; poll briefly so
        // a signed-in store returns its cookies before we decide auth state. A genuinely
        // empty store falls through to the timeout (bounded, one-time at launch).
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let cookies = await allCookies(store)
            if !cookies.isEmpty { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
        } while Date() < deadline
    }

    /// Warm up every provider's store concurrently before the first auth check.
    func warmUpAll(timeout: TimeInterval = 2.0) async {
        await withTaskGroup(of: Void.self) { group in
            for provider in AIProvider.allCases {
                let store = ProviderDataStores.store(for: provider)
                group.addTask { @MainActor in
                    await self.warmUp(store, timeout: timeout)
                }
            }
        }
    }

    private func allCookies(_ store: WKWebsiteDataStore) async -> [HTTPCookie] {
        await withCheckedContinuation { cont in
            store.httpCookieStore.getAllCookies { cont.resume(returning: $0) }
        }
    }
}
