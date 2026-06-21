import AppKit
import Foundation
import SwiftUI

final class DesklineSettings: ObservableObject {
    static let shared = DesklineSettings()

    @Published var hudOpacity: Double {
        didSet { persist() }
    }

    @Published var clickThrough: Bool {
        didSet { persist() }
    }

    @Published var hudVisible: Bool {
        didSet { persist() }
    }

    @Published var hudPositionLocked: Bool {
        didSet { persist() }
    }

    @Published var hudCustomX: Double? {
        didSet { persist() }
    }

    @Published var hudCustomY: Double? {
        didSet { persist() }
    }

    @Published var enabledProviders: Set<AIProvider> {
        didSet { persist() }
    }

    @Published var refreshInterval: TimeInterval {
        didSet { persist() }
    }

    /// 0 = auto-detect from Claude Code JSONL (shared key with ai-usage-counter).
    @Published var claudeSessionTokenLimit: Int {
        didSet { persist() }
    }

    @Published var claudeWeeklyTokenLimit: Int {
        didSet { persist() }
    }

    @Published var displayMode: DesklineDisplayMode {
        didSet { persist() }
    }

    @Published var menubarSource: AIProvider {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard
    private let enabledProvidersKey = "enabledProviders"
    private let hudOpacityKey = "hudOpacity"
    private let clickThroughKey = "clickThrough"
    private let hudVisibleKey = "hudVisible"
    private let hudPositionLockedKey = "hudPositionLocked"
    private let hudCustomXKey = "hudCustomX"
    private let hudCustomYKey = "hudCustomY"
    private let refreshIntervalKey = "refreshInterval"
    private let claudeSessionTokenLimitKey = "sessionTokenLimit"
    private let claudeWeeklyTokenLimitKey = "weeklyTokenLimit"
    private let displayModeKey = "displayMode"
    private let menubarSourceKey = "menubarSource"

    private init() {
        hudOpacity = defaults.object(forKey: hudOpacityKey) as? Double ?? 0.92
        clickThrough = defaults.bool(forKey: clickThroughKey)

        let resolvedMode: DesklineDisplayMode
        if let raw = defaults.string(forKey: displayModeKey) {
            resolvedMode = DesklineDisplayMode.migrated(from: raw)
        } else {
            resolvedMode = .deskline
        }
        displayMode = resolvedMode
        hudVisible = defaults.object(forKey: hudVisibleKey) as? Bool ?? (resolvedMode == .deskline)

        if let raw = defaults.string(forKey: menubarSourceKey),
           let source = AIProvider(rawValue: raw) {
            menubarSource = source
        } else {
            menubarSource = .claude
        }

        hudPositionLocked = defaults.bool(forKey: hudPositionLockedKey)
        refreshInterval = max(30, defaults.object(forKey: refreshIntervalKey) as? TimeInterval ?? 60)
        claudeSessionTokenLimit = defaults.object(forKey: claudeSessionTokenLimitKey) != nil
            ? defaults.integer(forKey: claudeSessionTokenLimitKey) : 0
        claudeWeeklyTokenLimit = defaults.object(forKey: claudeWeeklyTokenLimitKey) != nil
            ? defaults.integer(forKey: claudeWeeklyTokenLimitKey) : 0

        if defaults.object(forKey: hudCustomXKey) != nil {
            hudCustomX = defaults.double(forKey: hudCustomXKey)
            hudCustomY = defaults.double(forKey: hudCustomYKey)
        } else {
            hudCustomX = nil
            hudCustomY = nil
        }

        if let rawValues = defaults.stringArray(forKey: enabledProvidersKey) {
            let providers = Set(rawValues.compactMap(AIProvider.init(rawValue:)))
            enabledProviders = providers.isEmpty ? Set(AIProvider.allCases) : providers
        } else {
            enabledProviders = Set(AIProvider.allCases)
        }
    }

    var enabledProviderList: [AIProvider] {
        AIProvider.allCases.filter { enabledProviders.contains($0) }
    }

    var hudHasCustomPosition: Bool {
        hudCustomX != nil && hudCustomY != nil
    }

    var hudDraggable: Bool {
        !hudPositionLocked && !clickThrough
    }

    func effectiveClaudeSessionLimit(detected: Int) -> Int {
        if claudeSessionTokenLimit > 0 { return claudeSessionTokenLimit }
        return max(1, detected)
    }

    func effectiveClaudeWeeklyLimit(detected: Int) -> Int {
        if claudeWeeklyTokenLimit > 0 { return claudeWeeklyTokenLimit }
        return max(1, detected)
    }

    var showsFloatingHUD: Bool {
        hudVisible
    }

    func resetHUDPosition() {
        hudCustomX = nil
        hudCustomY = nil
    }

    func saveHUDOrigin(_ point: NSPoint) {
        hudCustomX = Double(point.x)
        hudCustomY = Double(point.y)
    }

    private func persist() {
        defaults.set(hudOpacity, forKey: hudOpacityKey)
        defaults.set(clickThrough, forKey: clickThroughKey)
        defaults.set(hudVisible, forKey: hudVisibleKey)
        defaults.set(hudPositionLocked, forKey: hudPositionLockedKey)
        defaults.set(refreshInterval, forKey: refreshIntervalKey)
        defaults.set(claudeSessionTokenLimit, forKey: claudeSessionTokenLimitKey)
        defaults.set(claudeWeeklyTokenLimit, forKey: claudeWeeklyTokenLimitKey)
        defaults.set(displayMode.rawValue, forKey: displayModeKey)
        defaults.set(menubarSource.rawValue, forKey: menubarSourceKey)
        defaults.set(enabledProviderList.map(\.rawValue), forKey: enabledProvidersKey)
        if let hudCustomX, let hudCustomY {
            defaults.set(hudCustomX, forKey: hudCustomXKey)
            defaults.set(hudCustomY, forKey: hudCustomYKey)
        } else {
            defaults.removeObject(forKey: hudCustomXKey)
            defaults.removeObject(forKey: hudCustomYKey)
        }
    }
}
