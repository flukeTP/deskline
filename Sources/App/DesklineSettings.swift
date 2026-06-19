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
    private let refreshIntervalKey = "refreshInterval"

    private init() {
        hudOpacity = defaults.object(forKey: hudOpacityKey) as? Double ?? 0.92
        clickThrough = defaults.bool(forKey: clickThroughKey)
        hudVisible = defaults.object(forKey: hudVisibleKey) as? Bool ?? true
        refreshInterval = max(30, defaults.object(forKey: refreshIntervalKey) as? TimeInterval ?? 60)

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

    private func persist() {
        defaults.set(hudOpacity, forKey: hudOpacityKey)
        defaults.set(clickThrough, forKey: clickThroughKey)
        defaults.set(hudVisible, forKey: hudVisibleKey)
        defaults.set(refreshInterval, forKey: refreshIntervalKey)
        defaults.set(enabledProviderList.map(\.rawValue), forKey: enabledProvidersKey)
    }
}
