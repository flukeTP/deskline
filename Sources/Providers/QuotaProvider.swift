import Foundation

/// Contract for per-provider quota readers. MVP shell uses stubs; parsers will be
/// copied/adapted from ai-usage-counter in follow-up work.
protocol QuotaProvider: Sendable {
    var provider: AIProvider { get }
    func fetchQuota() async -> QuotaSnapshot
}
