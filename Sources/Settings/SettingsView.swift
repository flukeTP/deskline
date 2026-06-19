import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: DesklineSettings
    @EnvironmentObject private var coordinator: QuotaCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("HUD") {
                Toggle("Show HUD bar", isOn: $settings.hudVisible)
                Toggle("Click-through (ignore mouse)", isOn: $settings.clickThrough)
                Slider(value: $settings.hudOpacity, in: 0.35...1.0) {
                    Text("Opacity")
                }
                Text("\(Int(settings.hudOpacity * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Providers") {
                ForEach(AIProvider.allCases) { provider in
                    Toggle(provider.displayName, isOn: binding(for: provider))
                }
                Text("MVP shell shows stub percentages until parsers are ported from ai-usage-counter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Refresh") {
                Picker("Interval", selection: $settings.refreshInterval) {
                    Text("30 sec").tag(30.0)
                    Text("60 sec").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                }
                Button("Refresh now") {
                    coordinator.refreshNow(enabled: settings.enabledProviderList)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 420)
        .padding()
        .onChange(of: settings.hudOpacity) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.clickThrough) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.hudVisible) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.enabledProviders) { _, _ in
            notifySettingsChanged()
            coordinator.refreshNow(enabled: settings.enabledProviderList)
        }
        .onChange(of: settings.refreshInterval) { _, _ in
            coordinator.restartTimer(settings: settings)
        }
    }

    private func binding(for provider: AIProvider) -> Binding<Bool> {
        Binding(
            get: { settings.enabledProviders.contains(provider) },
            set: { enabled in
                if enabled {
                    settings.enabledProviders.insert(provider)
                } else {
                    settings.enabledProviders.remove(provider)
                }
            }
        )
    }

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: .desklineSettingsDidChange, object: nil)
    }
}
