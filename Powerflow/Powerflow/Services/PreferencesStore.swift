import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    var theme: AppTheme {
        didSet { persist() }
    }
    var animationsEnabled: Bool {
        didSet { persist() }
    }
    var updateIntervalMs: Int {
        didSet { persist() }
    }
    var language: String {
        didSet { persist() }
    }
    var statusBarItem: StatusBarItem {
        didSet { persist() }
    }
    var statusBarShowCharging: Bool {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        updateIntervalMs = defaults.object(forKey: Keys.updateInterval) as? Int ?? 1500
        language = defaults.string(forKey: Keys.language) ?? "en"
        statusBarItem = StatusBarItem(rawValue: defaults.string(forKey: Keys.statusBarItem) ?? "") ?? .system
        statusBarShowCharging = defaults.object(forKey: Keys.statusBarShowCharging) as? Bool ?? true
    }

    var updateInterval: TimeInterval {
        max(0.5, Double(updateIntervalMs) / 1000)
    }

    func statusBarText(for resource: NormalizedResource) -> String {
        let value: Float
        if resource.isCharging && statusBarShowCharging {
            value = resource.systemIn
        } else {
            switch statusBarItem {
            case .system: value = resource.systemLoad
            case .screen: value = resource.data.brightnessPower
            case .heatpipe: value = resource.data.heatpipePower
            }
        }
        return String(format: "%.1f w", value)
    }

    private func persist() {
        defaults.set(theme.rawValue, forKey: Keys.theme)
        defaults.set(animationsEnabled, forKey: Keys.animationsEnabled)
        defaults.set(updateIntervalMs, forKey: Keys.updateInterval)
        defaults.set(language, forKey: Keys.language)
        defaults.set(statusBarItem.rawValue, forKey: Keys.statusBarItem)
        defaults.set(statusBarShowCharging, forKey: Keys.statusBarShowCharging)
    }

    private enum Keys {
        static let theme = "preference.theme"
        static let animationsEnabled = "preference.animationsEnabled"
        static let updateInterval = "preference.updateInterval"
        static let language = "preference.language"
        static let statusBarItem = "preference.statusBarItem"
        static let statusBarShowCharging = "preference.statusBarShowCharging"
    }
}
