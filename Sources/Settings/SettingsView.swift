import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: DesklineSettings
    @EnvironmentObject private var coordinator: QuotaCoordinator

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var keySheetProvider: AIProvider?
    @State private var keyInput = ""
    @State private var keySaving = false

    var body: some View {
        Form {
            Section("Display") {
                Picker("Mode", selection: $settings.displayMode) {
                    ForEach(DesklineDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text(settings.displayMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Menu bar provider", selection: $settings.menubarSource) {
                    ForEach(settings.enabledProviderList) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .disabled(settings.enabledProviderList.isEmpty)
                Text("Menu bar shows the Deskline icon and a single glance % for this provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Show floating strip", isOn: $settings.hudVisible)
                Text(settings.displayMode == .deskline
                    ? "Thin draggable strip on screen. Click the menu bar icon for a slide-down expand."
                    : "Wide draggable bar on screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if LoginItem.isAvailable {
                    Toggle("Open Deskline at login", isOn: $launchAtLogin)
                    Text("Keeps the always-on glance and alerts running after every restart.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Open at login is available in the built Deskline.app (not swift run).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Modules") {
                Toggle("Show Watchlist glance", isOn: $settings.showNasdaqModule)
                Text("Adds a stock-signal cell to the strip — net tilt of your watchlist (▲ up / ▼ down) from nasdaq-signal's alerts/state.json. Per-ticker detail is planned for the widget.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.showNasdaqModule && coordinator.nasdaqGlance == nil {
                    Text("No data yet — make sure ~/Documents/project/personal/nasdaq-signal/alerts/state.json exists.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if settings.displayMode == .deskline {
                Section("Slide-down panel") {
                    Slider(value: $settings.slideDownOpacity, in: 0.35...1.0) {
                        Text("Opacity")
                    }
                    Text("\(Int(settings.slideDownOpacity * 100))% — the panel shown when you click the menu bar icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if settings.hudVisible {
                Section("Floating strip") {
                    Toggle("Lock position", isOn: $settings.hudPositionLocked)
                    Toggle("Click-through (ignore mouse)", isOn: $settings.clickThrough)
                    Slider(value: $settings.hudOpacity, in: 0.35...1.0) {
                        Text("Opacity")
                    }
                    Text("\(Int(settings.hudOpacity * 100))% — the always-on floating strip.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reset position (top center)") {
                        settings.resetHUDPosition()
                        notifySettingsChanged()
                    }
                    if settings.clickThrough {
                        Text("Click-through disables dragging.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !settings.hudPositionLocked {
                        Text("Drag the floating bar to move it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Providers") {
                ForEach(AIProvider.allCases) { provider in
                    Toggle(provider.displayName, isOn: binding(for: provider))
                }
            }

            Section("Alerts") {
                Toggle("Highlight provider when usage is high", isOn: $settings.alertsEnabled)
                if settings.alertsEnabled {
                    Slider(value: $settings.warnThreshold, in: 50...95, step: 5) {
                        Text("Warn at")
                    }
                    Text("Outline the provider on the strip at \(Int(settings.warnThreshold))%.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.criticalThreshold, in: 80...100, step: 5) {
                        Text("Critical at")
                    }
                    Text("Pulse the provider on the strip at \(Int(settings.criticalThreshold))%.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Send a macOS notification when crossed", isOn: $settings.notificationsEnabled)
                    Text("Notifies once each time a provider crosses warn or critical, then re-arms after it drops back down. Requires running the built Deskline.app (not swift run).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Preview alert styles on the strip", isOn: $settings.previewAlerts)
                    Text("Temporarily forces warn + critical styling so you can see them without waiting for real usage. Turns off on relaunch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Accounts") {
                ForEach(AIProvider.allCases) { provider in
                    accountRow(for: provider)
                }
                Text("Sign in opens an in-app window so Deskline can capture session cookies for quota APIs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Refresh") {
                Picker("Local (Claude/Codex)", selection: $settings.refreshInterval) {
                    Text("30 sec").tag(30.0)
                    Text("60 sec").tag(60.0)
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                }
                Text("Local providers also refresh instantly when their usage files change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Online (Cursor/Gemini/…)", selection: $settings.remoteRefreshInterval) {
                    Text("2 min").tag(120.0)
                    Text("5 min").tag(300.0)
                    Text("10 min").tag(600.0)
                    Text("15 min").tag(900.0)
                }
                Text("Polled less often to avoid hitting provider rate limits. Refresh now always updates all.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let label = coordinator.lastRefreshedLabel {
                    Text("Last refresh: \(label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Refresh now") {
                    coordinator.refreshNow(enabled: settings.enabledProviderList)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 700)
        .padding()
        .sheet(item: $keySheetProvider) { keySheet(for: $0) }
        .onChange(of: settings.displayMode) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.menubarSource) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.hudOpacity) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.clickThrough) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.hudVisible) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.hudPositionLocked) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.enabledProviders) { _, newValue in
            if !newValue.contains(settings.menubarSource), let first = settings.enabledProviderList.first {
                settings.menubarSource = first
            }
            notifySettingsChanged()
            coordinator.refreshNow(enabled: settings.enabledProviderList)
        }
        .onChange(of: settings.refreshInterval) { _, _ in
            coordinator.restartTimer(settings: settings)
        }
        .onChange(of: launchAtLogin) { _, newValue in
            let applied = LoginItem.setEnabled(newValue)
            if applied != newValue { launchAtLogin = applied }
        }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
        .onChange(of: settings.showNasdaqModule) { _, _ in
            coordinator.reloadNasdaqGlance()
            notifySettingsChanged()
        }
        .onChange(of: settings.alertsEnabled) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.notificationsEnabled) { _, _ in notifySettingsChanged() }
        .onChange(of: settings.warnThreshold) { _, newValue in
            if settings.criticalThreshold < newValue { settings.criticalThreshold = newValue }
            notifySettingsChanged()
        }
        .onChange(of: settings.criticalThreshold) { _, newValue in
            if newValue < settings.warnThreshold { settings.warnThreshold = newValue }
            notifySettingsChanged()
        }
    }

    @ViewBuilder
    private func accountRow(for provider: AIProvider) -> some View {
        let auth = coordinator.authStates[provider] ?? .signedOut
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                    Text(authLabel(auth, provider: provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if auth == .signedIn {
                    Button("Sign out") {
                        Task { await coordinator.signOut(provider: provider) }
                    }
                }
            }
            if provider.supportsWebLogin {
                // Only the in-app window can capture the session cookie. Signing in via the
                // system browser uses a separate cookie jar, so it can't authenticate Deskline.
                HStack {
                    Button(auth == .signedIn ? "Re-sign in…" : "Sign in…") {
                        coordinator.presentLogin(for: provider)
                    }
                    if provider.sessionCookie != nil {
                        Button("Paste session token…") {
                            keyInput = ""
                            keySheetProvider = provider
                        }
                    }
                }
                if provider.sessionCookie != nil {
                    Text("If web sign-in is blocked (e.g. Google), paste the session cookie instead to get exact numbers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Local files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func keySheet(for provider: AIProvider) -> some View {
        let spec = provider.sessionCookie
        let site = (spec?.domain ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste \(provider.displayName) session token")
                .font(.headline)
            Text("In your browser, open \(site) → DevTools → Application → Cookies → \(site) → copy the value of \"\(spec?.name ?? "")\" and paste it here. It stays on your Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("\(spec?.name ?? "session token") value", text: $keyInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Spacer()
                Button("Cancel") { keySheetProvider = nil; keyInput = "" }
                Button("Save") { saveKey(for: provider) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || keySaving)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func saveKey(for provider: AIProvider) {
        keySaving = true
        let value = keyInput
        Task {
            _ = await SessionCookieInjector.set(value, for: provider)
            await coordinator.refreshAuthStates()
            coordinator.refreshNow(enabled: settings.enabledProviderList)
            keySaving = false
            keyInput = ""
            keySheetProvider = nil
        }
    }

    private func authLabel(_ auth: AuthState, provider: AIProvider) -> String {
        switch auth {
        case .signedIn:
            return provider.supportsLocalQuota ? "Signed in or local data" : "Signed in"
        case .signedOut:
            return provider.supportsLocalQuota ? "Local files if available" : "Not signed in"
        case .expired:
            return "Session expired"
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
