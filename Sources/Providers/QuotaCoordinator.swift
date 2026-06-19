import Foundation

@MainActor
final class QuotaCoordinator: ObservableObject {
    @Published private(set) var snapshots: [AIProvider: QuotaSnapshot] = [:]
    @Published private(set) var authStates: [AIProvider: AuthState] = [:]
    @Published private(set) var isRefreshing = false

    private let providers: [AIProvider: any DesklineQuotaProvider]
    private var refreshTimer: Timer?
    private var claudeWatcher: FileWatcher?
    private var codexWatcher: FileWatcher?

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
        startFileWatchers()
        scheduleRefresh(interval: settings.refreshInterval)
        Task { await refreshAuthStates() }
        Task { await refresh(enabled: settings.enabledProviderList) }
    }

    func restartTimer(settings: DesklineSettings) {
        scheduleRefresh(interval: settings.refreshInterval)
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        claudeWatcher = nil
        codexWatcher = nil
    }

    func refreshNow(enabled: [AIProvider]) {
        Task { await refresh(enabled: enabled) }
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

    func signOut(provider: AIProvider) async {
        guard let reader = providers[provider] else { return }
        await reader.signOut()
        authStates[provider] = .signedOut
        await refresh(enabled: DesklineSettings.shared.enabledProviderList)
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
        refreshTimer?.invalidate()
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
        defer { isRefreshing = false }

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
        }
    }
}
