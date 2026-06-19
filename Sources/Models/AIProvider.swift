import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable, Hashable {
    case claude
    case codex
    case cursor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "bolt.fill"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        }
    }
}

enum QuotaSource: String, Codable, Sendable {
    case stub
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
}
