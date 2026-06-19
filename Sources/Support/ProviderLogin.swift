import AppKit
import Foundation

/// Opens the system default browser for sign-in, then re-checks auth when the app becomes active.
@MainActor
enum ProviderLogin {
    private static var pendingProvider: AIProvider?
    private static var onComplete: (@MainActor () -> Void)?
    private static var observer: NSObjectProtocol?

    static func openInBrowser(
        for provider: AIProvider,
        onComplete: @escaping @MainActor () -> Void
    ) {
        guard BrowserAuth.openLogin(for: provider) else { return }

        pendingProvider = provider
        self.onComplete = onComplete

        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard pendingProvider != nil else { return }
                let done = self.onComplete
                clearPending()
                done?()
            }
        }
    }

    static func cancelPending() {
        clearPending()
    }

    private static func clearPending() {
        pendingProvider = nil
        onComplete = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
