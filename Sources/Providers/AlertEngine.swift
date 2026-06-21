import Foundation
import UserNotifications

/// Fires a macOS notification when a provider *crosses up* into warn/critical.
/// Fire-once per escalation: re-arms only after usage falls back below warn,
/// so a provider sitting at 88% does not notify on every refresh.
@MainActor
final class AlertEngine {
    private let settings: DesklineSettings
    private var lastLevel: [AIProvider: AlertLevel] = [:]
    private var authorized = false

    init(settings: DesklineSettings = .shared) {
        self.settings = settings
    }

    /// Ask once at launch. Safe to call when running outside an .app bundle —
    /// it simply leaves notifications unauthorized.
    func requestAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.authorized = granted }
        }
    }

    /// Evaluate the current snapshots and notify on any fresh escalation.
    func evaluate(snapshots: [AIProvider: QuotaSnapshot]) {
        for provider in settings.enabledProviderList {
            let pct = snapshots[provider]?.percentUsed
            let level = settings.alertLevel(forPercentUsed: pct)
            let escalated = AlertEngine.didEscalate(from: lastLevel[provider] ?? .none, to: level)
            lastLevel[provider] = level

            guard escalated, settings.notificationsEnabled else { continue }
            notify(provider: provider, level: level, percent: pct)
        }
    }

    /// Pure escalation rule: fire only when crossing *up* to a higher level.
    /// Same or lower level (cooling down, or steady-state) does not fire — that is the
    /// fire-once + re-arm behavior, isolated here so it is unit-testable.
    nonisolated static func didEscalate(from previous: AlertLevel, to current: AlertLevel) -> Bool {
        current.rank > previous.rank
    }

    /// Forget remembered levels so the next evaluation can re-fire (e.g. settings changed).
    func reset() {
        lastLevel.removeAll()
    }

    private func notify(provider: AIProvider, level: AlertLevel, percent: Double?) {
        guard authorized else { return }
        let pctText = percent.map { "\(Int($0.rounded()))%" } ?? "high"
        let content = UNMutableNotificationContent()
        switch level {
        case .critical:
            content.title = "\(provider.displayName) usage critical"
            content.body = "\(pctText) used — at or above your \(Int(settings.criticalThreshold))% limit."
        case .warn:
            content.title = "\(provider.displayName) usage high"
            content.body = "\(pctText) used — past your \(Int(settings.warnThreshold))% warning."
        case .none:
            return
        }
        content.sound = level == .critical ? .default : nil

        let request = UNNotificationRequest(
            identifier: "deskline.alert.\(provider.rawValue).\(level.rank)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
