import AppKit

if CommandLine.arguments.contains("--verify") {
    Task { @MainActor in
        let coordinator = QuotaCoordinator()
        await coordinator.refreshAuthStates()
        await coordinator.refreshAndWait(enabled: AIProvider.allCases)

        print("=== Deskline quota verify ===")
        for provider in AIProvider.allCases {
            let auth = coordinator.authStates[provider]?.rawValue ?? "unknown"
            if let snap = coordinator.snapshots[provider] {
                let pct = snap.percentUsed.map { String(format: "%.1f%%", $0) } ?? "—"
                print("\(provider.displayName): \(pct) [\(snap.source.rawValue)] auth=\(auth) detail=\(snap.detail ?? "-")")
            } else {
                print("\(provider.displayName): — [missing] auth=\(auth)")
            }
        }

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
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
