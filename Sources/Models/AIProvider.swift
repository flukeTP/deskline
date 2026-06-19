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
        self != .claude
    }

    var supportsLocalQuota: Bool {
        self == .claude || self == .codex
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
            source: .unavailable,
            detail: detail,
            lastUpdated: Date()
        )
    }

    static func fromAPI(_ provider: AIProvider, usage: ProviderUsage) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: provider,
            percentUsed: usage.glancePct,
            source: .api,
            detail: usage.planName,
            lastUpdated: usage.fetchedAt
        )
    }

    static func fromLocal(_ provider: AIProvider, usage: ProviderUsage, detail: String? = nil) -> QuotaSnapshot {
        QuotaSnapshot(
            provider: provider,
            percentUsed: usage.glancePct,
            source: .local,
            detail: detail,
            lastUpdated: usage.fetchedAt
        )
    }
}
