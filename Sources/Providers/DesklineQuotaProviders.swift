import Foundation

enum ClaudeLocalUsage {
    /// Build quota from ~/.claude/projects JSONL — same source as ai-usage-counter.
    static func providerUsage(from data: UsageData, settings: DesklineSettings = .shared) -> ProviderUsage? {
        let sessionLimit = settings.effectiveClaudeSessionLimit(detected: data.detectedSessionLimit)
        let weeklyLimit = settings.effectiveClaudeWeeklyLimit(detected: data.detectedWeeklyLimit)
        let hasData = data.totalSessions > 0 || data.currentBlock != nil || data.weeklyBlock.tokens > 0
        guard hasData else { return nil }

        var usage = ProviderUsage(fetchedAt: data.lastUpdated)

        if let block = data.currentBlock, block.isActive {
            usage.sessionPct = min(Double(block.tokens) / Double(sessionLimit) * 100, 100)
            usage.sessionResetAt = block.resetTime
        }

        if data.weeklyBlock.tokens > 0 {
            usage.weeklyPct = min(Double(data.weeklyBlock.tokens) / Double(weeklyLimit) * 100, 100)
            usage.weeklyResetAt = Date().addingTimeInterval(data.weeklyBlock.timeUntilReset)
        }

        guard usage.sessionPct != nil || usage.weeklyPct != nil else { return nil }
        return usage
    }
}

@MainActor
protocol DesklineQuotaProvider: AnyObject {
    var provider: AIProvider { get }
    func checkAuth() async -> AuthState
    func presentLogin(onComplete: @escaping @MainActor () -> Void)
    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void)
    func signOut() async
    func fetchQuota() async -> QuotaSnapshot
}

@MainActor
final class ClaudeQuotaProvider: DesklineQuotaProvider {
    let provider = AIProvider.claude
    private let engine = ClaudeQuotaEngine()

    func checkAuth() async -> AuthState {
        await engine.checkAuth()
    }

    func presentLogin(onComplete: @escaping @MainActor () -> Void) {
        engine.presentLogin(onComplete: onComplete)
    }

    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void) {
        engine.presentInAppLogin(onComplete: onComplete)
    }

    func signOut() async {
        await engine.signOut()
    }

    func fetchQuota() async -> QuotaSnapshot {
        // Prefer claude.ai's own usage numbers when signed in — they match the Plan
        // usage page exactly (server-computed). The local JSONL estimate can't, so it's
        // only a labeled fallback when not signed in.
        switch await engine.fetchUsage() {
        case .success(let api):
            return .fromAPI(.claude, usage: api)
        case .authExpired, .failure:
            let data = await ClaudeUsageParser.parse()
            if let local = ClaudeLocalUsage.providerUsage(from: data) {
                return .fromLocal(.claude, usage: local, detail: "Claude Code (estimate)")
            }
            return .unavailable(.claude, detail: "Sign in to claude.ai for exact usage")
        }
    }
}

@MainActor
final class CursorQuotaProvider: DesklineQuotaProvider {
    let provider = AIProvider.cursor
    private let engine = CursorQuotaEngine()

    func checkAuth() async -> AuthState { await engine.checkAuth() }
    func presentLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentLogin(onComplete: onComplete) }
    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentInAppLogin(onComplete: onComplete) }
    func signOut() async { await engine.signOut() }

    func fetchQuota() async -> QuotaSnapshot {
        switch await engine.fetchUsage() {
        case .success(let usage):
            return .fromAPI(.cursor, usage: usage)
        case .authExpired:
            return .unavailable(.cursor, detail: "Sign in to cursor.com")
        case .failure:
            return .unavailable(.cursor, detail: "Could not fetch Cursor usage")
        }
    }
}

@MainActor
final class CodexQuotaProvider: DesklineQuotaProvider {
    let provider = AIProvider.codex
    private let engine = CodexQuotaEngine()

    func checkAuth() async -> AuthState { await engine.checkAuth() }
    func presentLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentLogin(onComplete: onComplete) }
    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentInAppLogin(onComplete: onComplete) }
    func signOut() async { await engine.signOut() }

    func fetchQuota() async -> QuotaSnapshot {
        let local = await CodexLocalParser.parse()

        switch await engine.fetchUsage() {
        case .success(let api):
            return .fromAPI(.codex, usage: api)
        case .authExpired:
            if let local, local.glancePct != nil {
                return .fromLocal(.codex, usage: local, detail: "Codex local sessions")
            }
            return .unavailable(.codex, detail: "Sign in to ChatGPT or use Codex CLI")
        case .failure:
            if let local, local.glancePct != nil {
                return .fromLocal(.codex, usage: local, detail: "Codex local sessions")
            }
            return .unavailable(.codex, detail: "No Codex usage data")
        }
    }
}

@MainActor
final class GeminiQuotaProvider: DesklineQuotaProvider {
    let provider = AIProvider.gemini
    private let engine = GeminiQuotaEngine()

    func checkAuth() async -> AuthState { await engine.checkAuth() }
    func presentLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentLogin(onComplete: onComplete) }
    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentInAppLogin(onComplete: onComplete) }
    func signOut() async { await engine.signOut() }

    func fetchQuota() async -> QuotaSnapshot {
        switch await engine.fetchUsage() {
        case .success(let usage):
            return .fromAPI(.gemini, usage: usage)
        case .authExpired:
            return .unavailable(.gemini, detail: "Sign in to Gemini")
        case .failure:
            return .unavailable(.gemini, detail: "Could not read Gemini usage")
        }
    }
}

@MainActor
final class AntigravityQuotaProvider: DesklineQuotaProvider {
    let provider = AIProvider.antigravity
    private let engine = AntigravityQuotaEngine()

    func checkAuth() async -> AuthState { await engine.checkAuth() }
    func presentLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentLogin(onComplete: onComplete) }
    func presentInAppLogin(onComplete: @escaping @MainActor () -> Void) { engine.presentInAppLogin(onComplete: onComplete) }
    func signOut() async { await engine.signOut() }

    func fetchQuota() async -> QuotaSnapshot {
        switch await engine.fetchUsage() {
        case .success(let usage):
            return .fromAPI(.antigravity, usage: usage)
        case .authExpired:
            return .unavailable(.antigravity, detail: "Sign in to Antigravity")
        case .failure:
            return .unavailable(.antigravity, detail: "Antigravity language server not found")
        }
    }
}
