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
        let nasdaq = settings.showNasdaqModule ? coordinator.nasdaqGlance : nil

        // Per-ticker watchlist detail belongs only in the expanded slide-down panel,
        // never the always-on compact strip (keeps the strip a terse mood glance).
        let showDetail = density == .expanded && (nasdaq?.tickers.isEmpty == false)

        VStack(spacing: 0) {
            stripRow(segments: segments, nasdaq: nasdaq)
                .padding(.horizontal, density == .compact ? 12 : 16)
                .padding(.vertical, density == .compact ? 7 : 10)

            if showDetail, let nasdaq {
                Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5)
                WatchlistDetailView(glance: nasdaq)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
            }
        }
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
        .opacity(density == .compact ? settings.hudOpacity : settings.slideDownOpacity)
        .accessibilityLabel(accessibilityText(segments))
    }

    @ViewBuilder
    private func stripRow(segments: [QuotaSnapshot], nasdaq: NasdaqGlance?) -> some View {
        HStack(spacing: density == .compact ? 10 : 14) {
            if segments.isEmpty && nasdaq == nil {
                Text("No providers")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
            } else {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, snapshot in
                    if index > 0 {
                        stripDivider
                    }
                    ProviderStripCell(
                        snapshot: snapshot,
                        density: density,
                        alertLevel: alertLevel(for: snapshot, index: index)
                    )
                }

                if let nasdaq {
                    if !segments.isEmpty { stripDivider }
                    NasdaqStripCell(glance: nasdaq, density: density)
                }
            }

            if coordinator.isRefreshing {
                ProgressView().controlSize(.small).scaleEffect(0.45).tint(Color.hudAccent)
            }
        }
    }

    private var stripDivider: some View {
        Text("·")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.hudAccent.opacity(0.55))
    }

    private func alertLevel(for snapshot: QuotaSnapshot, index: Int) -> AlertLevel {
        if settings.previewAlerts {
            // Alternate so both styles are visible at a glance: odd = critical pulse, even = warn.
            return index.isMultiple(of: 2) ? .warn : .critical
        }
        return settings.alertLevel(forPercentUsed: snapshot.percentUsed)
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

    private var stripFractions: [Double] {
        guard let usage = snapshot.usage else { return [] }
        if let lanes = usage.quotaLanes, !lanes.isEmpty {
            var fractions: [Double] = []
            if let total = usage.sessionPct {
                fractions.append(min(total / 100, 1))
            }
            fractions.append(contentsOf: lanes.map { min($0.pct / 100, 1) })
            return fractions
        }
        return [usage.sessionPct, usage.weeklyPct]
            .compactMap { $0.map { min($0 / 100, 1) } }
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

            if stripFractions.isEmpty {
                Text("—")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(stripFractions.enumerated()), id: \.offset) { _, fraction in
                        StripMicroBar(fraction: fraction)
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
        if let total = usage.sessionPct,
           let lanes = usage.quotaLanes, lanes.count >= 2 {
            let auto = lanes[0].pct
            let api = lanes[1].pct
            return "\(Int(total))|\(Int(auto))|\(Int(api))"
        }
        let s = usage.sessionPct.map { String(format: "%.0f", $0) }
        let w = usage.weeklyPct.map { String(format: "%.0f", $0) }
        switch (s, w) {
        case let (s?, w?): return "\(s)|\(w)"
        case let (s?, nil): return "\(s)%"
        case let (nil, w?): return "\(w)%"
        default:
            if let lanes = usage.quotaLanes, !lanes.isEmpty {
                return lanes.map { String(format: "%.0f", $0.pct) }.joined(separator: "|")
            }
            return nil
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

struct NasdaqStripCell: View {
    let glance: NasdaqGlance
    let density: DesklineStripDensity

    private var tiltColor: Color {
        switch glance.tilt {
        case .bullish: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .bearish: return .red
        case .neutral: return .secondary
        }
    }

    /// Directional icon so the cell's tilt reads at a glance, before the numbers.
    private var tiltIcon: String {
        switch glance.tilt {
        case .bullish: return "arrow.up.right"
        case .bearish: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tiltIcon)
                .font(.system(size: density == .compact ? 11 : 13, weight: .bold))
                .foregroundStyle(tiltColor)

            if density == .expanded {
                Text("Watchlist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(glance.summary)
                .font(.system(size: density == .compact ? 9 : 10, weight: .bold, design: .monospaced))
                .foregroundStyle(tiltColor)
        }
        .help(helpText)
    }

    private var helpText: String {
        var text = "Watchlist: \(glance.up) up, \(glance.down) down, \(glance.flat) flat"
        if let asOf = glance.asOf {
            let fmt = RelativeDateTimeFormatter()
            text += " — updated \(fmt.localizedString(for: asOf, relativeTo: Date()))"
        }
        return text
    }
}

/// Per-ticker watchlist breakdown shown under the strip in the expanded slide-down panel.
/// Flipped tickers (changed since last seen) are pulled to the front and marked.
struct WatchlistDetailView: View {
    let glance: NasdaqGlance

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 8, alignment: .leading)]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text("WATCHLIST")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                if glance.flippedCount > 0 {
                    Text("⚡\(glance.flippedCount) flipped")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.hudAccent)
                }
                Spacer()
                if let asOf = glance.asOf {
                    Text(RelativeDateTimeFormatter().localizedString(for: asOf, relativeTo: Date()))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                ForEach(glance.tickers) { ticker in
                    TickerChip(ticker: ticker)
                }
            }
        }
        .frame(minWidth: 220, alignment: .leading)
    }
}

private struct TickerChip: View {
    let ticker: TickerSignal

    private var color: Color {
        switch ticker.direction {
        case .up: return Color(red: 0.19, green: 0.82, blue: 0.35)
        case .down: return .red
        case .flat: return Color.white.opacity(0.5)
        }
    }

    private var arrow: String {
        switch ticker.direction {
        case .up: return "▲"
        case .down: return "▼"
        case .flat: return "•"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if ticker.flipped {
                Text("⚡")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.hudAccent)
            }
            Text(ticker.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
            Text(arrow)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(ticker.flipped ? Color.hudAccent.opacity(0.16) : Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().stroke(ticker.flipped ? Color.hudAccent.opacity(0.6) : Color.clear, lineWidth: 0.5)
        )
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
