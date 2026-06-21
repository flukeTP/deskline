import Foundation

@MainActor
final class QuotaCoordinator: ObservableObject {
    @Published private(set) var snapshots: [AIProvider: QuotaSnapshot] = [:]
    @Published private(set) var authStates: [AIProvider: AuthState] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var uiTick = Date()

    private let providers: [AIProvider: any DesklineQuotaProvider]
    private var refreshTimer: Timer?
    private var uiTimer: Timer?
    private var claudeWatcher: FileWatcher?
    private var codexWatcher: FileWatcher?
    private var currentRefreshInterval: TimeInterval = 60

    var refreshProgress: Double {
        guard let last = lastRefreshedAt, let next = nextRefreshAt else { return 0 }
        let total = next.timeIntervalSince(last)
        guard total > 0 else { return 0 }
        let elapsed = uiTick.timeIntervalSince(last)
        return min(max(elapsed / total, 0), 1)
    }

    var secondsUntilRefresh: Int? {
        guard let next = nextRefreshAt else { return nil }
        return max(0, Int(next.timeIntervalSince(uiTick).rounded()))
    }

    var lastRefreshedLabel: String? {
        guard let last = lastRefreshedAt else { return nil }
        let secs = Int(uiTick.timeIntervalSince(last))
        if secs < 5 { return "just now" }
        if secs < 60 { return "\(secs)s ago" }
        let mins = secs / 60
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    init(providers: [AIProvider: any DesklineQuotaProvider]? = nil) {
        self.providers = providers ?? [
            .claude: ClaudeQuotaProvider(),
            .cursor: CursorQuotaProvider(),
            .codex: CodexQuotaProvider(),
            .gemini: GeminiQuotaProvider(),
            .antigravity: AntigravityQuotaProvider(),
        ]
    }

    func start(settings: DesklineSettings) {
        stop()
        currentRefreshInterval = settings.refreshInterval
        startFileWatchers()
        startUITimer()
        scheduleRefresh(interval: settings.refreshInterval)
        Task { await refreshAuthStates() }
        Task { await refresh(enabled: settings.enabledProviderList) }
    }

    func restartTimer(settings: DesklineSettings) {
        currentRefreshInterval = settings.refreshInterval
        scheduleRefresh(interval: settings.refreshInterval)
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        uiTimer?.invalidate()
        uiTimer = nil
        claudeWatcher = nil
        codexWatcher = nil
    }

    func refreshNow(enabled: [AIProvider]) {
        Task { await refresh(enabled: enabled) }
    }

    func refreshAndWait(enabled: [AIProvider]) async {
        await refresh(enabled: enabled)
    }

    func refreshAuthStates() async {
        for provider in AIProvider.allCases {
            guard let reader = providers[provider] else { continue }
            authStates[provider] = await reader.checkAuth()
        }
    }

    func presentLogin(for provider: AIProvider) {
        guard let reader = providers[provider] else { return }
        reader.presentLogin { [weak self] in
            Task { await self?.refreshAuthStates() }
            Task { await self?.refresh(enabled: DesklineSettings.shared.enabledProviderList) }
        }
    }

    func presentInAppLogin(for provider: AIProvider) {
        guard let reader = providers[provider] else { return }
        reader.presentInAppLogin { [weak self] in
            Task { await self?.refreshAuthStates() }
            Task { await self?.refresh(enabled: DesklineSettings.shared.enabledProviderList) }
        }
    }

    func signOut(provider: AIProvider) async {
        guard let reader = providers[provider] else { return }
        await reader.signOut()
        authStates[provider] = .signedOut
        await refresh(enabled: DesklineSettings.shared.enabledProviderList)
    }

    private func startUITimer() {
        uiTimer?.invalidate()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.uiTick = Date()
                NotificationCenter.default.post(name: .desklineMenubarTick, object: nil)
            }
        }
    }

    private func markRefreshScheduled() {
        let anchor = lastRefreshedAt ?? Date()
        nextRefreshAt = anchor.addingTimeInterval(currentRefreshInterval)
    }

    private func startFileWatchers() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let claudeDir = home.appendingPathComponent(".claude/projects").path
        claudeWatcher = FileWatcher(path: claudeDir) { [weak self] in
            Task { await self?.refresh(enabled: DesklineSettings.shared.enabledProviderList) }
        }

        let codexDir = home.appendingPathComponent(".codex/sessions").path
        codexWatcher = FileWatcher(path: codexDir) { [weak self] in
            Task { await self?.refresh(enabled: DesklineSettings.shared.enabledProviderList) }
        }
    }

    private func scheduleRefresh(interval: TimeInterval) {
        currentRefreshInterval = interval
        refreshTimer?.invalidate()
        markRefreshScheduled()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let enabled = DesklineSettings.shared.enabledProviderList
            Task { await self.refresh(enabled: enabled) }
        }
        refreshTimer = timer
    }

    private func refresh(enabled: [AIProvider]) async {
        guard !enabled.isEmpty else {
            snapshots = [:]
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshedAt = Date()
            markRefreshScheduled()
        }

        await withTaskGroup(of: QuotaSnapshot.self) { group in
            for provider in enabled {
                guard let reader = providers[provider] else { continue }
                group.addTask { @MainActor in
                    await reader.fetchQuota()
                }
            }

            var next: [AIProvider: QuotaSnapshot] = [:]
            for await snapshot in group {
                next[snapshot.provider] = snapshot
            }
            snapshots = next
            NotificationCenter.default.post(name: .desklineQuotaDidChange, object: nil)
        }
    }
}
