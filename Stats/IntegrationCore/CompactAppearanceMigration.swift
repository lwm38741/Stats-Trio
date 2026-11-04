import Foundation

enum CompactAppearanceMigration {
    static func apply(to defaults: UserDefaults) {
        guard defaults.integer(forKey: "StatsTrioCompactAppearanceVersion") < 2 else { return }
        defaults.set("none", forKey: "Network_speed_icon")
        defaults.set("left", forKey: "Network_speed_valueAlignment")
        defaults.set("4", forKey: "CombinedModules_spacing")
        defaults.set(2, forKey: "StatsTrioCompactAppearanceVersion")
    }
}
