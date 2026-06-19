import AppKit
import Foundation

enum BrowserAuth {
    @discardableResult
    static func openLogin(for provider: AIProvider) -> Bool {
        guard let url = provider.loginURL else { return false }
        return NSWorkspace.shared.open(url)
    }
}

extension AIProvider {
    var loginURL: URL? {
        switch self {
        case .claude:
            return URL(string: "https://claude.ai/login")
        case .codex:
            return URL(string: "https://chatgpt.com/auth/login")
        case .cursor:
            return URL(string: "https://cursor.com/login")
        case .gemini:
            return URL(
                string: "https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fgemini.google.com%2Fapp"
            )
        case .antigravity:
            return URL(
                string: "https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fantigravity.google%2F"
            )
        }
    }
}
