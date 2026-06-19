import SwiftUI

struct HUDBarView: View {
    @EnvironmentObject private var coordinator: QuotaCoordinator
    @EnvironmentObject private var settings: DesklineSettings

    var body: some View {
        let enabled = settings.enabledProviderList
        let segments = enabled.compactMap { coordinator.snapshots[$0] }

        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if segments.isEmpty {
                Text("No providers selected")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, snapshot in
                    if index > 0 {
                        Text("·")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    Text(snapshot.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(color(for: snapshot))
                }
            }

            if coordinator.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.65)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }
        }
        .opacity(settings.hudOpacity)
        .accessibilityLabel(hudAccessibilityLabel(segments))
    }

    private func color(for snapshot: QuotaSnapshot) -> Color {
        guard let percent = snapshot.percentUsed else { return .secondary }
        switch percent {
        case ..<70: return .primary
        case ..<90: return .orange
        default: return .red
        }
    }

    private func hudAccessibilityLabel(_ segments: [QuotaSnapshot]) -> String {
        segments.map { snap in
            if let detail = snap.detail, snap.percentUsed == nil {
                return "\(snap.provider.displayName): \(detail)"
            }
            return snap.label
        }.joined(separator: ", ")
    }
}
