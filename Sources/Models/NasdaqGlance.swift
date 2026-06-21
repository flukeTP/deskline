import Foundation

/// A compact stock-signal glance sourced from nasdaq-signal's `alerts/state.json`
/// (a `{ "TICKER": "up" | "down" | "flat" }` map written by its background scorer).
/// Separate from AI `QuotaSnapshot` — different semantics, rendered as its own strip cell.
struct NasdaqGlance: Equatable {
    enum Tilt {
        case bullish
        case bearish
        case neutral
    }

    let up: Int
    let down: Int
    let flat: Int
    let asOf: Date?

    var total: Int { up + down + flat }

    /// Net direction of the watchlist, used to color the cell.
    var tilt: Tilt {
        if up > down { return .bullish }
        if down > up { return .bearish }
        return .neutral
    }

    /// e.g. "6▲ 2▼" — flat is omitted to keep the strip terse.
    var summary: String {
        var parts: [String] = []
        if up > 0 { parts.append("\(up)▲") }
        if down > 0 { parts.append("\(down)▼") }
        if parts.isEmpty { parts.append("\(flat)•") }
        return parts.joined(separator: " ")
    }

    /// Parse the raw `{ ticker: signal }` map. Unknown signal strings count as flat.
    static func from(stateMap: [String: String], asOf: Date?) -> NasdaqGlance? {
        guard !stateMap.isEmpty else { return nil }
        var up = 0, down = 0, flat = 0
        for value in stateMap.values {
            switch value.lowercased() {
            case "up": up += 1
            case "down": down += 1
            default: flat += 1
            }
        }
        return NasdaqGlance(up: up, down: down, flat: flat, asOf: asOf)
    }
}
