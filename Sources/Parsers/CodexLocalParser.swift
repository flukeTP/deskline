import Foundation

// Shared Codex usage parsing for chatgpt.com API payloads and local session JSONL.
enum CodexUsageFormat {
    static func parseRateLimits(_ rateLimits: [String: Any]) -> ProviderUsage? {
        var root: [String: Any] = ["rate_limit": rateLimits]
        if let plan = rateLimits["plan_type"] as? String {
            root["plan_type"] = plan
        }
        return parseWhamUsage(root)
    }

    static func parseWhamUsage(_ root: [String: Any]) -> ProviderUsage? {
        let rl = (root["rate_limit"] as? [String: Any])
              ?? (root["rate_limits"] as? [String: Any])
              ?? root

        func window(_ keys: [String]) -> [String: Any]? {
            for k in keys { if let d = rl[k] as? [String: Any] { return d } }
            return nil
        }
        let primary = window(["primary_window", "primary"])
        let secondary = window(["secondary_window", "secondary"])

        func parseWindow(_ d: [String: Any]?) -> (pct: Double?, reset: Date?, durationSecs: Double?) {
            guard let d else { return (nil, nil, nil) }
            let pct = providerPct(d["used_percent"] ?? d["usage_percent"] ?? d["used_percentage"])
            var reset: Date? = nil
            if let s = providerNum(d["resets_in_seconds"] ?? d["reset_after_seconds"] ?? d["resets_after_seconds"]) {
                reset = Date().addingTimeInterval(s)
            } else if let at = d["resets_at"] ?? d["reset_at"] {
                reset = providerDate(at)
            }
            var dur = providerNum(d["limit_window_seconds"] ?? d["window_seconds"])
            if dur == nil, let mins = providerNum(d["window_minutes"]) { dur = mins * 60 }
            return (pct, reset, dur)
        }

        var p = parseWindow(primary)
        var s = parseWindow(secondary)
        if let pd = p.durationSecs, let sd = s.durationSecs, pd > sd {
            swap(&p, &s)
        }

        guard p.pct != nil || s.pct != nil else { return nil }
        var u = ProviderUsage(fetchedAt: Date())
        u.sessionPct = p.pct
        u.sessionResetAt = p.reset
        u.weeklyPct = s.pct
        u.weeklyResetAt = s.reset
        u.planName = (root["plan_type"] as? String)?.capitalized
        return u
    }
}

// Reads the latest Codex rate_limits snapshot from ~/.codex/sessions rollout JSONL files.
// Each token_count event may include primary (short window) and secondary (weekly) usage %.
enum CodexLocalParser {
    static func parse() async -> ProviderUsage? {
        await Task.detached(priority: .utility) { parseSync() }.value
    }

    private static func parseSync() -> ProviderUsage? {
        let fm = FileManager.default
        let root = codexHome().appendingPathComponent("sessions")
        guard fm.fileExists(atPath: root.path) else { return nil }

        let files = rolloutFiles(under: root)
            .sorted { $0.modified > $1.modified }
            .prefix(40)
            .map(\.url)

        var best: (eventAt: Date, usage: ProviderUsage)?
        for url in files {
            guard let candidate = latestTokenUsage(in: url) else { continue }
            if best == nil || candidate.eventAt > best!.eventAt {
                best = candidate
            }
        }
        return best?.usage
    }

    private static func codexHome() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    private struct RolloutFile {
        let url: URL
        let modified: Date
    }

    private static func rolloutFiles(under root: URL) -> [RolloutFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var out: [RolloutFile] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            guard name.hasPrefix("rollout-"), name.hasSuffix(".jsonl") else { continue }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            out.append(RolloutFile(url: url, modified: modified))
        }
        return out
    }

    private static func latestTokenUsage(in url: URL) -> (eventAt: Date, usage: ProviderUsage)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var lastMatch: (eventAt: Date, usage: ProviderUsage)?
        for line in lines(in: handle) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["type"] as? String == "event_msg",
                  let payload = obj["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let rateLimits = payload["rate_limits"] as? [String: Any],
                  let usage = CodexUsageFormat.parseRateLimits(rateLimits) else {
                continue
            }
            let eventAt = providerDate(obj["timestamp"]) ?? .distantPast
            lastMatch = (eventAt, usage)
        }
        return lastMatch
    }

    private static func lines(in handle: FileHandle) -> AnySequence<String> {
        AnySequence {
            var iterator = LineIterator(handle: handle)
            return AnyIterator {
                iterator.next()
            }
        }
    }

    private struct LineIterator: IteratorProtocol {
        private let handle: FileHandle
        private var buffer = Data()

        init(handle: FileHandle) {
            self.handle = handle
        }

        mutating func next() -> String? {
            while true {
                if let range = buffer.firstRange(of: Data([0x0A])) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                    buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                    let line = String(data: lineData, encoding: .utf8)?
                        .trimmingCharacters(in: .newlines)
                    if let line, !line.isEmpty { return line }
                    continue
                }
                let chunk = try? handle.read(upToCount: 65_536)
                guard let chunk, !chunk.isEmpty else {
                    guard !buffer.isEmpty else { return nil }
                    let line = String(data: buffer, encoding: .utf8)?
                        .trimmingCharacters(in: .newlines)
                    buffer.removeAll()
                    return line?.isEmpty == false ? line : nil
                }
                buffer.append(chunk)
            }
        }
    }
}
