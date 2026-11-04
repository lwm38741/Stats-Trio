import Foundation

enum CompactAppearanceMigration {
    static func apply(to defaults: UserDefaults) {
        guard defaults.integer(forKey: "StatsTrioCompactAppearanceVersion") < 3 else { return }
        defaults.set("none", forKey: "Network_speed_icon")
        defaults.set("left", forKey: "Network_speed_valueAlignment")
        defaults.set("0", forKey: "CombinedModules_spacing")
        defaults.set(3, forKey: "StatsTrioCompactAppearanceVersion")
    }
}
