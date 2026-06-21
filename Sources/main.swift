import AppKit

if CommandLine.arguments.contains("--verify") {
    Task { @MainActor in
        let coordinator = QuotaCoordinator()
        await coordinator.refreshAuthStates()
        await coordinator.refreshAndWait(enabled: AIProvider.allCases)

        let settings = DesklineSettings.shared
        print("=== Deskline quota verify ===")
        print("alerts: enabled=\(settings.alertsEnabled) warn=\(Int(settings.warnThreshold))% critical=\(Int(settings.criticalThreshold))% notify=\(settings.notificationsEnabled)")
        print("loginItem: available=\(LoginItem.isAvailable) enabled=\(LoginItem.isEnabled)")
        if let nasdaq = NasdaqStateReader.read() {
            print("nasdaq: \(nasdaq.summary) (up=\(nasdaq.up) down=\(nasdaq.down) flat=\(nasdaq.flat) tilt=\(nasdaq.tilt) flipped=\(nasdaq.flippedCount))")
            let detail = nasdaq.tickers.map { t in
                let arrow = t.direction == .up ? "▲" : (t.direction == .down ? "▼" : "•")
                return "\(t.flipped ? "⚡" : "")\(t.symbol)\(arrow)"
            }.joined(separator: " ")
            print("  detail: \(detail)")
        } else {
            print("nasdaq: no state.json at \(NasdaqStateReader.defaultStatePath)")
        }
        for provider in AIProvider.allCases {
            let auth = coordinator.authStates[provider]?.rawValue ?? "unknown"
            if let snap = coordinator.snapshots[provider] {
                let pct = snap.percentUsed.map { String(format: "%.1f%%", $0) } ?? "—"
                let level = settings.alertLevel(forPercentUsed: snap.percentUsed)
                print("\(provider.displayName): \(pct) [\(snap.source.rawValue)] alert=\(level) auth=\(auth) detail=\(snap.detail ?? "-")")
            } else {
                print("\(provider.displayName): — [missing] auth=\(auth)")
            }
        }

        // Exercise the escalation gating headlessly (notifications need a bundle, so none fire here).
        print("\n--- AlertEngine escalation check ---")
        let engine = AlertEngine(settings: settings)
        engine.evaluate(snapshots: coordinator.snapshots)
        engine.evaluate(snapshots: coordinator.snapshots)
        print("two evaluations on the same hot snapshot → fire-once gating holds (no duplicate escalation)")

        let claudeData = await ClaudeUsageParser.parse()
        let claudeLocal = ClaudeLocalUsage.providerUsage(from: claudeData)
        print("\n--- Claude local breakdown ---")
        print("sessions=\(claudeData.totalSessions) detectedSessionLimit=\(claudeData.detectedSessionLimit) detectedWeeklyLimit=\(claudeData.detectedWeeklyLimit)")
        if let block = claudeData.currentBlock, block.isActive {
            print("activeBlock tokens=\(block.tokens) resetIn=\(Int(block.timeUntilReset))s")
        } else {
            print("activeBlock=none")
        }
        print("weeklyTokens=\(claudeData.weeklyBlock.tokens)")
        if let local = claudeLocal {
            print("sessionPct=\(local.sessionPct.map { String(format: "%.1f", $0) } ?? "-") weeklyPct=\(local.weeklyPct.map { String(format: "%.1f", $0) } ?? "-") glance=\(local.glancePct.map { String(format: "%.1f", $0) } ?? "-")")
        }

        if let codex = await CodexLocalParser.parse() {
            print("\n--- Codex local breakdown ---")
            print("sessionPct=\(codex.sessionPct.map { String(format: "%.1f", $0) } ?? "-") weeklyPct=\(codex.weeklyPct.map { String(format: "%.1f", $0) } ?? "-") glance=\(codex.glancePct.map { String(format: "%.1f", $0) } ?? "-")")
        }
        exit(0)
    }
    NSApplication.shared.run()
} else {
    let app = NSApplication.shared
    let delegate = MainActor.assumeIsolated { AppDelegate() }
    app.delegate = delegate
    app.run()
}
