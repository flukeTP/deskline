import SwiftUI

enum DesklineStripDensity {
    case compact
    case expanded
}

struct DesklineStripView: View {
    var density: DesklineStripDensity = .compact
    var showTopAccent: Bool = true

    @EnvironmentObject private var coordinator: QuotaCoordinator
    @EnvironmentObject private var settings: DesklineSettings

    var body: some View {
        let segments = settings.enabledProviderList.compactMap { coordinator.snapshots[$0] }

        HStack(spacing: density == .compact ? 10 : 14) {
            if segments.isEmpty {
                Text("No providers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            } else {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, snapshot in
                    if index > 0 {
                        Text("·")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.hudAccent.opacity(0.55))
                    }
                    ProviderStripCell(
                        snapshot: snapshot,
                        density: density,
                        alertLevel: settings.alertLevel(forPercentUsed: snapshot.percentUsed)
                    )
                }
            }

            if coordinator.isRefreshing {
                ProgressView().controlSize(.small).scaleEffect(0.45).tint(Color.hudAccent)
            }
        }
        .padding(.horizontal, density == .compact ? 12 : 16)
        .padding(.vertical, density == .compact ? 7 : 10)
        .background(Color.hudBg)
        .overlay(alignment: .top) {
            if showTopAccent {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.hudAccent, Color.hudAccent.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
            }
        }
        .clipShape(StripShape(expanded: density == .expanded))
        .overlay {
            StripShape(expanded: density == .expanded)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
        }
        .opacity(settings.hudOpacity)
        .accessibilityLabel(accessibilityText(segments))
    }

    private func accessibilityText(_ segments: [QuotaSnapshot]) -> String {
        segments.map { snap in
            let pct = snap.percentUsed.map { String(format: "%.0f%%", $0) } ?? "unavailable"
            return "\(snap.provider.displayName) \(pct)"
        }.joined(separator: ", ")
    }
}

private struct StripShape: Shape {
    let expanded: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = expanded ? 10 : 8
        var path = Path()
        if expanded {
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: 0, bottomLeading: radius,
                    bottomTrailing: radius, topTrailing: 0
                )
            )
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        }
        return path
    }
}

struct ProviderStripCell: View {
    let snapshot: QuotaSnapshot
    let density: DesklineStripDensity
    var alertLevel: AlertLevel = .none

    @State private var pulse = false

    private var sessionFraction: Double? {
        snapshot.usage?.sessionPct.map { min($0 / 100, 1) }
    }

    private var weeklyFraction: Double? {
        snapshot.usage?.weeklyPct.map { min($0 / 100, 1) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ProviderIcon.swiftUI(for: snapshot.provider, size: density == .compact ? 13 : 15)

            if density == .expanded {
                Text(snapshot.provider.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            if sessionFraction == nil && weeklyFraction == nil {
                Text("—")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    if let sessionFraction {
                        StripMicroBar(fraction: sessionFraction)
                    }
                    if let weeklyFraction {
                        StripMicroBar(fraction: weeklyFraction)
                    }
                }
            }

            if let label = pctLabel {
                Text(label)
                    .font(.system(size: density == .compact ? 9 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(pctColor)
            }
        }
        .padding(.horizontal, alertLevel.isHot ? 5 : 0)
        .padding(.vertical, alertLevel.isHot ? 2 : 0)
        .background(alertChrome)
        .help(helpText)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: alertLevel.isHot) { _, _ in startPulseIfNeeded() }
    }

    @ViewBuilder
    private var alertChrome: some View {
        if alertLevel.isHot {
            let isCritical = alertLevel == .critical
            Capsule()
                .fill(alertLevel.color.opacity(isCritical ? 0.18 : 0.12))
                .overlay {
                    Capsule().stroke(alertLevel.color.opacity(isCritical ? 0.9 : 0.55), lineWidth: 1)
                }
                .opacity(isCritical ? (pulse ? 1.0 : 0.45) : 1.0)
        }
    }

    private func startPulseIfNeeded() {
        guard alertLevel == .critical else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    private var pctLabel: String? {
        guard let usage = snapshot.usage else { return nil }
        let s = usage.sessionPct.map { String(format: "%.0f", $0) }
        let w = usage.weeklyPct.map { String(format: "%.0f", $0) }
        switch (s, w) {
        case let (s?, w?): return "\(s)|\(w)"
        case let (s?, nil): return "\(s)%"
        case let (nil, w?): return "\(w)%"
        default: return nil
        }
    }

    private var pctColor: Color {
        if let pct = snapshot.percentUsed {
            return HUDTheme.barColor(fraction: pct / 100)
        }
        return .secondary
    }

    private var helpText: String {
        let bars = snapshot.allBarVMs.map { "\($0.label) \($0.usedText)/\($0.limitText)" }.joined(separator: ", ")
        if bars.isEmpty { return "\(snapshot.provider.displayName): unavailable" }
        return "\(snapshot.provider.displayName): \(bars)"
    }
}

struct StripMicroBar: View {
    let fraction: Double

    private var color: Color { HUDTheme.barColor(fraction: fraction) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(color).frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(width: 30, height: 3)
    }
}
