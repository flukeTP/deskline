import AppKit

@MainActor
final class MenubarPresenter {
    weak var statusItem: NSStatusItem?

    private var lastTitle: String = ""

    func update(coordinator: QuotaCoordinator, settings: DesklineSettings) {
        guard let button = statusItem?.button else { return }
        let source = settings.menubarSource
        guard settings.enabledProviders.contains(source) else {
            applyFallback(button: button, coordinator: coordinator, settings: settings)
            return
        }

        let glance = glanceText(for: source, coordinator: coordinator)
        let title = " \(glance)"
        guard title != lastTitle else { return }
        lastTitle = title

        button.image = MenuBarIcon.load()
        button.image?.size = NSSize(width: 16, height: 16)
        button.title = title
        button.toolTip = "\(source.displayName) — \(glance) (click to expand)"
    }

    private func applyFallback(button: NSButton, coordinator: QuotaCoordinator, settings: DesklineSettings) {
        let first = settings.enabledProviderList.first
        if let first, first != settings.menubarSource {
            settings.menubarSource = first
            update(coordinator: coordinator, settings: settings)
            return
        }
        button.image = MenuBarIcon.load()
        button.title = " —"
    }

    private func glanceText(for provider: AIProvider, coordinator: QuotaCoordinator) -> String {
        guard let snap = coordinator.snapshots[provider], let usage = snap.usage else { return "—" }

        if usage.sessionAtLimit, let reset = usage.sessionResetAt, reset > Date() {
            return UsageFormatters.formatSessionCountdown(reset.timeIntervalSinceNow)
        }
        if let pct = usage.sessionPct {
            return String(format: "%.0f%%", pct)
        }
        if usage.weeklyAtLimit, let reset = usage.weeklyResetAt, reset > Date() {
            return UsageFormatters.formatResetClock(reset)
        }
        if let pct = usage.weeklyPct {
            return String(format: "%.0f%%", pct)
        }
        if let pct = snap.percentUsed {
            return String(format: "%.0f%%", pct)
        }
        return "—"
    }
}
