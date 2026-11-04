import Foundation
import CoreFoundation

public struct MigrationResult { public let didMigrate: Bool }

public enum PreferenceMigration {
    public static func migrate(source: [String: Any], destination: UserDefaults) -> MigrationResult {
        guard destination.integer(forKey: "StatsTrioMigrationVersion") < 1 else {
            return MigrationResult(didMigrate: false)
        }
        var values: [String: Any] = [
            "CombinedModules": true, "CombinedModules_popup": false,
            "CombinedModules_spacing": "2", "CombinedModules_separator": false,
            "CPU_widget": "mini", "RAM_widget": "mini", "Sensors_widget": "sensors",
            "Network_widget": "speed", "CPU_updateInterval": 2, "RAM_updateInterval": 2,
            "CPU_updateTopInterval": 2, "RAM_updateTopInterval": 2,
            "CPU_processes": 10, "RAM_processes": 10, "Sensors_hid": true,
            "sensor_Hottest CPU": true, "sensor_PSTR": true,
            "Network_publicIP": false, "systemWidgetsUpdates_state": false
        ]
        let boolKeys = Set(["CPU_state", "RAM_state", "Sensors_state", "Network_state",
                            "Sensors_hid", "Sensors_unknown", "Network_interfaceDetails",
                            "Network_VPNMode", "CPU_hyperhreading", "CPU_usagePerCore",
                            "CPU_splitValue", "CPU_clustersGroup", "RAM_splitValue",
                            "sensor_Hottest CPU", "sensor_Hottest SOC", "sensor_PSTR"])
        let intKeys = Set(ModuleID.allCases.flatMap { id in
            ["\(id.rawValue)_updateInterval", "\(id.rawValue)_updateTopInterval",
             "\(id.rawValue)_position", "\(id.rawValue)_processes"]
        } + ["Network_updateICMPInterval"])
        let stringKeys = Set(["Network_interface", "Network_reader", "Network_speedUnit", "Network_base"])
        for id in ModuleID.allCases { values["\(id.rawValue)_state"] = true }
        for (index, id) in ModuleID.allCases.enumerated() { values["\(id.rawValue)_position"] = index }
        for (key, raw) in source {
            if boolKeys.contains(key), let n = raw as? NSNumber,
               CFGetTypeID(n) == CFBooleanGetTypeID() {
                values[key] = n.boolValue
            } else if intKeys.contains(key), let n = raw as? NSNumber,
                      CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue == Double(n.intValue) {
                let range = key.hasSuffix("_position") ? 0...20 : key.hasSuffix("_processes") ? 0...20 : 1...60
                if range.contains(n.intValue) { values[key] = n.intValue }
            } else if stringKeys.contains(key), let text = raw as? String, text.count <= 128 {
                values[key] = text
            }
        }
        values.forEach { destination.set($0.value, forKey: $0.key) }
        destination.set(1, forKey: "StatsTrioMigrationVersion")
        return MigrationResult(didMigrate: true)
    }
}
