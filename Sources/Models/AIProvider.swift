import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable, Hashable {
    case claude
    case codex
    case cursor
    case gemini
    case antigravity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .gemini: return "Gemini"
        case .antigravity: return "Antigravity"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "bolt.fill"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        case .gemini: return "sparkle"
        case .antigravity: return "a.circle.fill"
        }
    }

    var supportsWebLogin: Bool {
        true
    }

    var supportsLocalQuota: Bool {
        self == .claude || self == .codex
    }

    /// The auth cookie a user can paste to sign in when the in-app web login is blocked
    /// (e.g. Google SSO). `nil` for providers that auth through Google / DOM scraping.
    var sessionCookie: (name: String, domain: String)? {
        switch self {
        case .claude: return ("sessionKey", ".claude.ai")
        case .codex: return ("__Secure-next-auth.session-token", ".chatgpt.com")
        case .cursor: return ("WorkosCursorSessionToken", ".cursor.com")
        case .gemini, .antigravity: return nil
        }
    }

    /// ChatGPT's next-auth session JWT is split across `.0`/`.1` cookies when large.
    var sessionCookieChunked: Bool { self == .codex }

    var sessionBarLabel: String {
        switch self {
        case .cursor: return "Total"
        default: return "Current Session"
        }
    }

    var weeklyBarLabel: String {
        switch self {
        case .cursor: return "API Usage"
        default: return "Weekly"
        }
    }
}

enum QuotaSource: String, Codable, Sendable {
    case local
    case api
    case unavailable
}

struct QuotaSnapshot: Sendable, Identifiable {
    let provider: AIProvider
    var percentUsed: Double?
    var usage: ProviderUsage?
    var source: QuotaSource
    var detail: String?
    var lastUpdated: Date

    var id: String { provider.id }

    var label: String {
        guard let percentUsed else { return "\(provider.displayName) —" }
        return "\(provider.displayName) \(Int(percentUsed.rounded()))%"
    }

    static func unavailable(_ provider: AIProvider, detail: String? = nil) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: provider,
            percentUsed: nil,
            usage: nil,
            source: .unavailable,
            detail: detail,
            lastUpdated: Date()
        )
    }

    static func fromAPI(_ provider: AIProvider, usage: ProviderUsage) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: provider,
            percentUsed: usage.glancePct,
            usage: usage,
            source: .api,
            detail: usage.planName,
            lastUpdated: usage.fetchedAt
        )
    }

    static func fromLocal(_ provider: AIProvider, usage: ProviderUsage, detail: String? = nil) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: provider,
            percentUsed: usage.glancePct,
            usage: usage,
            source: .local,
            detail: detail,
            lastUpdated: usage.fetchedAt
        )
    }
}
