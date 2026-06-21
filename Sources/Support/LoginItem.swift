import Foundation
import ServiceManagement

/// Thin wrapper over SMAppService for "open Deskline at login".
/// Only meaningful from the built `.app` (needs a registered bundle); `swift run`
/// has no bundle, so `isAvailable` is false there and toggling is a no-op.
enum LoginItem {
    /// SMAppService.mainApp needs a real bundle id — absent under `swift run`.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    /// True when Deskline is currently registered to launch at login.
    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister. Returns the resulting enabled state; logs and returns
    /// the unchanged state on failure so the UI can stay truthful.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard isAvailable else { return false }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Deskline: login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
        }
        return isEnabled
    }
}
