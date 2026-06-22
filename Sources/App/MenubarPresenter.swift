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
        let hot = hottestAlert(coordinator: coordinator, settings: settings)

        // Cache on glance + badge level so the dot updates when a provider heats up/cools down.
        let cacheKey = " \(glance)|\(hot.level.rank)"
        guard cacheKey != lastTitle else { return }
        lastTitle = cacheKey

        button.image = MenuBarIcon.load()
        button.image?.size = NSSize(width: 16, height: 16)
        button.attributedTitle = menubarTitle(glance: glance, level: hot.level)
        if hot.level.isHot, let provider = hot.provider {
            let label = hot.level == .critical ? "critical" : "high"
            button.toolTip = "\(provider.displayName) usage \(label) — \(source.displayName) \(glance) (click to expand)"
        } else {
            button.toolTip = "\(source.displayName) — \(glance) (click to expand)"
        }
    }

    /// The most severe alert level across enabled providers, with the worst offender.
    private func hottestAlert(coordinator: QuotaCoordinator, settings: DesklineSettings) -> (level: AlertLevel, provider: AIProvider?) {
        var worst: AlertLevel = .none
        var which: AIProvider?
        for provider in settings.enabledProviderList {
            let level = settings.alertLevel(forPercentUsed: coordinator.snapshots[provider]?.percentUsed)
            if level.rank > worst.rank {
                worst = level
                which = provider
            }
        }
        return (worst, which)
    }

    private func menubarTitle(glance: String, level: AlertLevel) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if level.isHot {
            let dotColor: NSColor = level == .critical ? .systemRed : .systemOrange
            result.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: dotColor]))
        }
        result.append(NSAttributedString(string: glance))
        let full = NSRange(location: 0, length: result.length)
        result.addAttribute(.font, value: NSFont.menuBarFont(ofSize: 0), range: full)
        return result
    }

    private func applyFallback(button: NSButton, coordinator: QuotaCoordinator, settings: DesklineSettings) {
        let first = settings.enabledProviderList.first
        if let first, first != settings.menubarSource {
            settings.menubarSource = first
            update(coordinator: coordinator, settings: settings)
            return
        }
        button.image = MenuBarIcon.load()
        button.attributedTitle = NSAttributedString(string: " —")
        lastTitle = ""
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
