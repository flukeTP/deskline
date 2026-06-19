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

    private let defaults = UserDefaults.standard
    private let enabledProvidersKey = "enabledProviders"
    private let hudOpacityKey = "hudOpacity"
    private let clickThroughKey = "clickThrough"
    private let hudVisibleKey = "hudVisible"
    private let hudPositionLockedKey = "hudPositionLocked"
    private let hudCustomXKey = "hudCustomX"
    private let hudCustomYKey = "hudCustomY"
    private let refreshIntervalKey = "refreshInterval"

    private init() {
        hudOpacity = defaults.object(forKey: hudOpacityKey) as? Double ?? 0.92
        clickThrough = defaults.bool(forKey: clickThroughKey)
        hudVisible = defaults.object(forKey: hudVisibleKey) as? Bool ?? true
        hudPositionLocked = defaults.bool(forKey: hudPositionLockedKey)
        refreshInterval = max(30, defaults.object(forKey: refreshIntervalKey) as? TimeInterval ?? 60)

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
