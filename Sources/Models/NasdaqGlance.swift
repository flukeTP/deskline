import Foundation

/// One watchlist ticker's current signal, plus whether it just flipped vs the
/// last-acknowledged state.
struct TickerSignal: Equatable, Identifiable {
    enum Direction {
        case up
        case down
        case flat

        init(rawSignal: String) {
            switch rawSignal.lowercased() {
            case "up": self = .up
            case "down": self = .down
            default: self = .flat
            }
        }
    }

    let symbol: String
    let direction: Direction
    let flipped: Bool

    var id: String { symbol }
}

/// A compact stock-signal glance sourced from nasdaq-signal's `alerts/state.json`
/// (a `{ "TICKER": "up" | "down" | "flat" }` map written by its background scorer).
/// Separate from AI `QuotaSnapshot` — different semantics, rendered as its own strip cell.
struct NasdaqGlance: Equatable {
    enum Tilt {
        case bullish
        case bearish
        case neutral
    }

    /// Sorted for the detail list: flipped first, then up → down → flat, then alphabetical.
    let tickers: [TickerSignal]
    let asOf: Date?

    var up: Int { tickers.filter { $0.direction == .up }.count }
    var down: Int { tickers.filter { $0.direction == .down }.count }
    var flat: Int { tickers.filter { $0.direction == .flat }.count }
    var total: Int { tickers.count }
    var flippedCount: Int { tickers.filter(\.flipped).count }

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

    /// Parse the raw `{ ticker: signal }` map. `baseline` is the last-acknowledged
    /// map; a ticker is "flipped" when it existed before and its direction changed.
    static func from(
        stateMap: [String: String],
        baseline: [String: String] = [:],
        asOf: Date?
    ) -> NasdaqGlance? {
        guard !stateMap.isEmpty else { return nil }

        let tickers = stateMap.map { symbol, signal -> TickerSignal in
            let direction = TickerSignal.Direction(rawSignal: signal)
            let previously = baseline[symbol].map(TickerSignal.Direction.init(rawSignal:))
            let flipped = previously != nil && previously != direction
            return TickerSignal(symbol: symbol, direction: direction, flipped: flipped)
        }
        .sorted(by: sortOrder)

        return NasdaqGlance(tickers: tickers, asOf: asOf)
    }

    private static func sortOrder(_ a: TickerSignal, _ b: TickerSignal) -> Bool {
        if a.flipped != b.flipped { return a.flipped }            // flipped first
        if a.direction != b.direction {
            return directionRank(a.direction) < directionRank(b.direction)
        }
        return a.symbol < b.symbol
    }

    private static func directionRank(_ d: TickerSignal.Direction) -> Int {
        switch d {
        case .up: return 0
        case .down: return 1
        case .flat: return 2
        }
    }
}
