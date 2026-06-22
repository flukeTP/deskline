import Foundation

@MainActor
final class QuotaCoordinator: ObservableObject {
    @Published private(set) var snapshots: [AIProvider: QuotaSnapshot] = [:]
    @Published private(set) var nasdaqGlance: NasdaqGlance?
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
    private var lastRemoteFetchedAt: Date?

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
        // Load persisted cookies from disk before checking auth, otherwise every
        // provider reads empty and reports signed-out on a fresh launch.
        Task {
            await CookieWarmer.shared.warmUpAll()
            await refreshAuthStates()
            await refresh(enabled: settings.enabledProviderList, forceRemote: true)
        }
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
        Task { await refresh(enabled: enabled, forceRemote: true) }
    }

    func refreshAndWait(enabled: [AIProvider]) async {
        await refresh(enabled: enabled, forceRemote: true)
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
            Task { await self?.refresh(enabled: DesklineSettings.shared.enabledProviderList, forceRemote: true) }
        }
    }

    func presentInAppLogin(for provider: AIProvider) {
        guard let reader = providers[provider] else { return }
        reader.presentInAppLogin { [weak self] in
            Task { await self?.refreshAuthStates() }
            Task { await self?.refresh(enabled: DesklineSettings.shared.enabledProviderList, forceRemote: true) }
        }
    }

    func signOut(provider: AIProvider) async {
        guard let reader = providers[provider] else { return }
        await reader.signOut()
        authStates[provider] = .signedOut
        await refresh(enabled: DesklineSettings.shared.enabledProviderList, forceRemote: true)
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

    /// Pure rule for whether online providers are due for a re-poll. Isolated for testing.
    nonisolated static func remoteIsDue(
        forceRemote: Bool,
        lastRemoteFetchedAt: Date?,
        now: Date,
        interval: TimeInterval
    ) -> Bool {
        if forceRemote { return true }
        guard let last = lastRemoteFetchedAt else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    func reloadNasdaqGlance() {
        nasdaqGlance = DesklineSettings.shared.showNasdaqModule ? NasdaqStateReader.read() : nil
    }

    /// Mark the current watchlist state as seen: clears flip highlights until the
    /// next change. Called when the user opens the detail (slide-down) panel.
    func acknowledgeWatchlist() {
        guard DesklineSettings.shared.showNasdaqModule,
              let raw = NasdaqStateReader.readRaw() else { return }
        WatchlistBaseline.save(raw.map)
        reloadNasdaqGlance()
    }

    /// `forceRemote` bypasses the remote throttle (used on launch, manual refresh, and
    /// after sign-in/out). Otherwise online providers are only re-fetched once
    /// `remoteRefreshInterval` has elapsed, while local (file-backed) providers always
    /// refresh — they have no rate limit and are also driven by file watchers.
    private func refresh(enabled: [AIProvider], forceRemote: Bool = false) async {
        reloadNasdaqGlance()

        let enabledSet = Set(enabled)
        // Carry over existing snapshots for still-enabled providers; drop disabled ones.
        var merged = snapshots.filter { enabledSet.contains($0.key) }

        let now = Date()
        let remoteDue = QuotaCoordinator.remoteIsDue(
            forceRemote: forceRemote,
            lastRemoteFetchedAt: lastRemoteFetchedAt,
            now: now,
            interval: DesklineSettings.shared.remoteRefreshInterval
        )
        let toFetch = enabled.filter { $0.supportsLocalQuota || remoteDue }

        guard !toFetch.isEmpty else {
            snapshots = merged
            return
        }

        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefreshedAt = Date()
            markRefreshScheduled()
        }

        await withTaskGroup(of: QuotaSnapshot.self) { group in
            for provider in toFetch {
                guard let reader = providers[provider] else { continue }
                group.addTask { @MainActor in
                    await reader.fetchQuota()
                }
            }
            for await snapshot in group {
                merged[snapshot.provider] = snapshot
            }
        }

        if remoteDue && toFetch.contains(where: { !$0.supportsLocalQuota }) {
            lastRemoteFetchedAt = now
        }
        snapshots = merged
        NotificationCenter.default.post(name: .desklineQuotaDidChange, object: nil)
    }
}
