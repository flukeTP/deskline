import Foundation

/// Reads nasdaq-signal's local `alerts/state.json`. Local-first, like the Claude/Codex
/// parsers — no server required. The file is refreshed by nasdaq-signal's background
/// scorer (committed by GitHub Actions), so the glance reflects the last synced signals.
enum NasdaqStateReader {
    /// Default path mirrors the dev-path convention already used by MenuBarIcon.
    static var defaultStatePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/project/personal/nasdaq-signal/alerts/state.json")
            .path
    }

    /// Raw `{ ticker: signal }` map plus the file's modification date.
    static func readRaw(path: String = defaultStatePath) -> (map: [String: String], asOf: Date?)? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }
        let modified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        return (raw, modified)
    }

    /// Convenience: build a glance against the persisted baseline (for flip detection).
    static func read(path: String = defaultStatePath) -> NasdaqGlance? {
        guard let raw = readRaw(path: path) else { return nil }
        return NasdaqGlance.from(stateMap: raw.map, baseline: WatchlistBaseline.load(), asOf: raw.asOf)
    }
}

/// Persists the last-acknowledged watchlist state so "flips" can be highlighted until
/// the user opens the detail panel (which re-acknowledges).
enum WatchlistBaseline {
    private static let key = "watchlistBaseline"

    static func load() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }

    static func save(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
