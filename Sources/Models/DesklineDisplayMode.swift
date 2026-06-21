import Foundation

enum DesklineDisplayMode: String, CaseIterable, Codable, Identifiable {
    /// Thin floating strip + minimal menu bar + slide-down expand (Deskline default).
    case deskline
    /// Wide multi-column bar (legacy / power-user).
    case detailedBar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deskline: return "Deskline strip"
        case .detailedBar: return "Detailed bar"
        }
    }

    var detail: String {
        switch self {
        case .deskline:
            return "Thin glance strip on screen; menu bar shows icon + %. Click opens a slim slide-down panel."
        case .detailedBar:
            return "Wide draggable bar with full provider columns (previous layout)."
        }
    }

    /// Migrate stored values from older hybrid / floatingHUD modes.
    static func migrated(from raw: String) -> DesklineDisplayMode {
        switch raw {
        case "hybrid", Self.deskline.rawValue: return .deskline
        case "floatingHUD", Self.detailedBar.rawValue: return .detailedBar
        default: return .deskline
        }
    }
}
