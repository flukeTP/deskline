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

    static func read(path: String = defaultStatePath) -> NasdaqGlance? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return nil }

        let modified = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        return NasdaqGlance.from(stateMap: raw, asOf: modified)
    }
}
