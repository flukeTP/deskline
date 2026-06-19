import Foundation

final class QuotaCoordinator: ObservableObject {
    @Published private(set) var snapshots: [AIProvider: QuotaSnapshot] = [:]
    @Published private(set) var isRefreshing = false

    private let providers: [AIProvider: any QuotaProvider]
    private var refreshTimer: Timer?

    init(providers: [AIProvider: any QuotaProvider]? = nil) {
        self.providers = providers ?? Dictionary(
            uniqueKeysWithValues: AIProvider.allCases.map { ($0, StubQuotaProvider(provider: $0)) }
        )
    }

    func start(settings: DesklineSettings) {
        stop()
        scheduleRefresh(interval: settings.refreshInterval)
        Task { await refresh(enabled: settings.enabledProviderList) }
    }

    func restartTimer(settings: DesklineSettings) {
        scheduleRefresh(interval: settings.refreshInterval)
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refreshNow(enabled: [AIProvider]) {
        Task { await refresh(enabled: enabled) }
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
                group.addTask { await reader.fetchQuota() }
            }

            var next: [AIProvider: QuotaSnapshot] = [:]
            for await snapshot in group {
                next[snapshot.provider] = snapshot
            }
            snapshots = next
        }
    }
}
