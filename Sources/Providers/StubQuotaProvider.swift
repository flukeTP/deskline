import Foundation

struct StubQuotaProvider: QuotaProvider {
    let provider: AIProvider

    func fetchQuota() async -> QuotaSnapshot {
        let seed = Double(abs(provider.rawValue.hashValue % 55)) + 18
        return QuotaSnapshot(
            provider: provider,
            percentUsed: seed,
            source: .stub,
            detail: "Stub data — parser not wired yet",
            lastUpdated: Date()
        )
    }
}
