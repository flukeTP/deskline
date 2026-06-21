import SwiftUI

enum HUDLayout {
    static let columnWidth: CGFloat = 204
}

enum HUDBarLayout {
    case horizontal
    case vertical
}

enum HUDBarStyle {
    case floating
    case popup
}

struct HUDBarView: View {
    var layout: HUDBarLayout = .horizontal
    var style: HUDBarStyle = .floating

    @EnvironmentObject private var coordinator: QuotaCoordinator
    @EnvironmentObject private var settings: DesklineSettings

    var body: some View {
        let enabled = settings.enabledProviderList
        let segments = enabled.compactMap { coordinator.snapshots[$0] }

        Group {
            if layout == .vertical {
                verticalBody(segments: segments)
            } else {
                horizontalBody(segments: segments)
            }
        }
        .fixedSize(horizontal: layout == .horizontal, vertical: true)
        .background(style == .floating ? Color.hudBg : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if style == .floating {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            }
        }
        .opacity(style == .floating ? settings.hudOpacity : 1)
        .allowsHitTesting(true)
        .accessibilityLabel(hudAccessibilityLabel(segments))
    }

    @ViewBuilder
    private func horizontalBody(segments: [QuotaSnapshot]) -> some View {
        VStack(spacing: 0) {
            if segments.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, snapshot in
                        if index > 0 {
                            Rectangle().fill(Color.hudDivider).frame(width: 1)
                        }
                        ProviderHUDColumn(snapshot: snapshot)
                            .frame(width: HUDLayout.columnWidth)
                    }
                }
            }
            refreshFooter
        }
    }

    @ViewBuilder
    private func verticalBody(segments: [QuotaSnapshot]) -> some View {
        VStack(spacing: 0) {
            if segments.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: segments.count > 3) {
                    VStack(spacing: 0) {
                        ForEach(Array(segments.enumerated()), id: \.element.id) { index, snapshot in
                            if index > 0 {
                                Rectangle().fill(Color.hudDivider).frame(height: 1)
                            }
                            ProviderHUDColumn(snapshot: snapshot)
                        }
                    }
                }
                .frame(maxHeight: segments.count > 3 ? 420 : nil)
            }
            refreshFooter
        }
    }

    @ViewBuilder
    private var refreshFooter: some View {
        if coordinator.isRefreshing {
            Rectangle().fill(Color.hudDivider).frame(height: 1)
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).scaleEffect(0.55).tint(Color.white.opacity(0.5))
                Text("Updating…")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.35))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.5))
            Text("No providers selected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func hudAccessibilityLabel(_ segments: [QuotaSnapshot]) -> String {
        segments.map { snap in
            let bars = snap.allBarVMs.map { "\($0.label) \(String(format: "%.0f%%", $0.fraction * 100))" }.joined(separator: ", ")
            if bars.isEmpty { return "\(snap.provider.displayName): unavailable" }
            return "\(snap.provider.displayName): \(bars)"
        }.joined(separator: "; ")
    }
}
