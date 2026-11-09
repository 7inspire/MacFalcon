import Foundation

/// Copies only Pulse preferences that still make sense after the bundle identifier changes.
enum SettingsMigration {
    static let legacyDomain = "com.example.pulse-monitor"
    static let marker = "didMigratePulsePreferences"
    static let keys = ["interval", "backgroundHistory", "priorityRules", "appearanceMode", "accentColor", "appLanguage"]

    static func migrate(defaults: UserDefaults = .standard, legacy: [String: Any]? = nil) {
        guard !defaults.bool(forKey: marker) else { return }
        let old = legacy ?? defaults.persistentDomain(forName: legacyDomain) ?? [:]
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = old[key] { defaults.set(value, forKey: key) }
        }
        defaults.set(true, forKey: marker)
    }
}
