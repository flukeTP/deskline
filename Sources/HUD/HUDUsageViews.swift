import SwiftUI

extension Color {
    static let hudBg = Color(red: 0.051, green: 0.051, blue: 0.059)
    static let hudDivider = Color.white.opacity(0.07)
    static let hudAccent = Color(red: 1.0, green: 0.62, blue: 0.0)
    static let hudHaikuGreen = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let hudOpusBlue = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let hudSonnetCyan = Color(red: 0.20, green: 0.68, blue: 0.90)
}

enum AlertLevel {
    case none
    case warn
    case critical

    var isHot: Bool { self != .none }

    var rank: Int {
        switch self {
        case .none: return 0
        case .warn: return 1
        case .critical: return 2
        }
    }

    var color: Color {
        switch self {
        case .none: return .clear
        case .warn: return .orange
        case .critical: return .red
        }
    }
}

enum HUDTheme {
    static func tint(for provider: AIProvider) -> Color {
        switch provider {
        case .claude: return .hudAccent
        case .codex: return .hudHaikuGreen
        case .cursor: return Color(red: 0.55, green: 0.72, blue: 1.0)
        case .gemini: return .hudOpusBlue
        case .antigravity: return Color(red: 0.70, green: 0.48, blue: 1.0)
        }
    }

    static func barColor(fraction: Double) -> Color {
        if fraction >= 1.0 { return .red }
        if fraction >= 0.9 { return .orange }
        if fraction >= 0.7 { return Color(red: 1, green: 0.75, blue: 0) }
        return .hudAccent
    }
}

struct UsageBarVM: Identifiable {
    let id: String
    var label: String
    var icon: String
    var iconColor: Color
    var fraction: Double
    var usedText: String
    var limitText: String
    var resetLabel: String
    var isActive: Bool
}

enum UsageFormatters {
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "< 1m"
    }

    static func formatSessionCountdown(_ secs: TimeInterval) -> String {
        let s = max(0, Int(secs))
        if s < 60 { return "\(s)s" }
        let m = s / 60
        let h = m / 60
        if h >= 4 { return ">4h" }
        if h >= 3 { return "<4h" }
        if h >= 2 { return "<3h" }
        if h >= 1 { return "<2h" }
        return "\(m)m"
    }

    static func formatResetClock(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "EEE h:mma"
        fmt.amSymbol = "AM"
        fmt.pmSymbol = "PM"
        return fmt.string(from: date)
    }
}

extension QuotaSnapshot {
    var sessionBarVM: UsageBarVM? {
        guard let usage, let pct = usage.sessionPct else { return nil }
        let fraction = min(pct / 100.0, 1.0)
        let atLimit = usage.sessionAtLimit
        var reset = "—"
        if let r = usage.sessionResetAt, r > Date() {
            if provider == .claude && source == .local && atLimit {
                reset = "Resets in \(UsageFormatters.formatSessionCountdown(r.timeIntervalSinceNow))"
            } else {
                reset = provider == .cursor
                    ? "Resets \(UsageFormatters.formatResetClock(r))"
                    : "Resets in \(UsageFormatters.formatDuration(r.timeIntervalSinceNow))"
            }
        }
        let usedText: String
        if provider == .claude && source == .local && atLimit,
           let r = usage.sessionResetAt, r > Date() {
            usedText = UsageFormatters.formatSessionCountdown(r.timeIntervalSinceNow)
        } else {
            usedText = String(format: "%.2f%%", pct)
        }
        return UsageBarVM(
            id: "\(provider.id)-session",
            label: provider.sessionBarLabel,
            icon: "clock.fill",
            iconColor: HUDTheme.tint(for: provider),
            fraction: fraction,
            usedText: usedText,
            limitText: atLimit ? "LIMIT REACHED" : "100%",
            resetLabel: reset,
            isActive: true
        )
    }

    var weeklyBarVM: UsageBarVM? {
        guard let usage, let pct = usage.weeklyPct else { return nil }
        let fraction = min(pct / 100.0, 1.0)
        let atLimit = usage.weeklyAtLimit
        var reset = "—"
        if let r = usage.weeklyResetAt, r > Date() {
            reset = "Resets \(UsageFormatters.formatResetClock(r))"
        }
        let usedText: String
        if provider == .claude && source == .local && atLimit,
           let r = usage.weeklyResetAt, r > Date() {
            usedText = UsageFormatters.formatResetClock(r)
        } else {
            usedText = String(format: "%.2f%%", pct)
        }
        return UsageBarVM(
            id: "\(provider.id)-weekly",
            label: provider.weeklyBarLabel,
            icon: "calendar",
            iconColor: .hudSonnetCyan,
            fraction: fraction,
            usedText: usedText,
            limitText: atLimit ? "LIMIT REACHED" : "100%",
            resetLabel: reset,
            isActive: true
        )
    }

    var quotaBarVMs: [UsageBarVM] {
        guard let lanes = usage?.quotaLanes else { return [] }
        return lanes.map { lane in
            let reset: String
            if let resetAt = lane.resetAt, resetAt > Date() {
                reset = "Resets in \(UsageFormatters.formatDuration(resetAt.timeIntervalSinceNow))"
            } else if let resetText = lane.resetText, !resetText.isEmpty {
                reset = resetText
            } else {
                reset = "—"
            }
            let atLimit = lane.pct >= 99.99
            return UsageBarVM(
                id: "\(provider.id)-\(lane.id)",
                label: lane.label,
                icon: "gauge.with.dots.needle.bottom.50percent",
                iconColor: HUDTheme.tint(for: provider),
                fraction: min(lane.pct / 100.0, 1.0),
                usedText: String(format: "%.2f%%", lane.pct),
                limitText: atLimit ? "LIMIT REACHED" : "100%",
                resetLabel: reset,
                isActive: true
            )
        }
    }

    var allBarVMs: [UsageBarVM] {
        var bars: [UsageBarVM] = []
        if let session = sessionBarVM { bars.append(session) }
        if let weekly = weeklyBarVM { bars.append(weekly) }
        bars.append(contentsOf: quotaBarVMs)
        return bars
    }
}

struct HUDUsageBarRow: View {
    let vm: UsageBarVM
    var compact: Bool = false

    private var pct: Double { vm.fraction * 100 }
    private var barColor: Color { HUDTheme.barColor(fraction: vm.fraction) }

    private var infoText: String {
        if vm.usedText.contains("%") { return "" }
        if vm.limitText.isEmpty { return vm.usedText }
        return "\(vm.usedText) / \(vm.limitText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 5) {
                Image(systemName: vm.icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(vm.iconColor)
                Text(vm.label)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 2)
                if vm.isActive && vm.fraction > 0 {
                    Text(String(format: "%.1f%%", pct))
                        .font(.system(size: compact ? 10 : 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(barColor)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [barColor.opacity(0.9), barColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1, max(0, vm.fraction)))
                        .animation(.easeOut(duration: 0.5), value: vm.fraction)
                }
            }
            .frame(height: compact ? 6 : 8)
            .cornerRadius(4)

            if !compact || !vm.resetLabel.isEmpty {
                HStack {
                    Text(infoText)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(vm.resetLabel)
                        .font(.system(size: 9))
                        .foregroundStyle(barColor.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

struct ProviderHUDColumn: View {
    let snapshot: QuotaSnapshot

    private var bars: [UsageBarVM] { snapshot.allBarVMs }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ProviderIcon.swiftUI(for: snapshot.provider, size: 16)
                Text(snapshot.provider.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if snapshot.provider == .claude && snapshot.source == .local {
                    Text("Claude Code")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                } else if snapshot.source == .local {
                    Text("local")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                }
            }

            if bars.isEmpty {
                Text(snapshot.detail ?? "Not connected")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.35))
            } else {
                ForEach(bars) { bar in
                    HUDUsageBarRow(vm: bar, compact: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
