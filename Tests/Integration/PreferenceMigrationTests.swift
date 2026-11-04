import Foundation

final class PreferenceMigrationTests: XCTestCase {
    func testAllowlistAndIdempotency() {
        let suite = "local.statstrio.tests.\(UUID().uuidString)"
        let destination = UserDefaults(suiteName: suite)!
        defer { destination.removePersistentDomain(forName: suite) }
        let source: [String: Any] = ["CPU_updateInterval": 2, "sensor_Hottest CPU": true,
                                    "sensor_PSTR": false, "access_token": "private", "GPU_state": true]
        XCTAssertTrue(PreferenceMigration.migrate(source: source, destination: destination).didMigrate)
        XCTAssertEqual(destination.integer(forKey: "CPU_updateInterval"), 2)
        XCTAssertTrue(destination.bool(forKey: "CombinedModules"))
        XCTAssertFalse(destination.bool(forKey: "CombinedModules_popup"))
        XCTAssertNil(destination.object(forKey: "access_token"))
        XCTAssertNil(destination.object(forKey: "GPU_state"))
        XCTAssertFalse(destination.bool(forKey: "sensor_PSTR"))
        destination.set(5, forKey: "CPU_updateInterval")
        XCTAssertFalse(PreferenceMigration.migrate(source: source, destination: destination).didMigrate)
        XCTAssertEqual(destination.integer(forKey: "CPU_updateInterval"), 5)
        XCTAssertEqual(source["CPU_updateInterval"] as? Int, 2)
    }

    func testMissingAndMalformedValuesUseSafeDefaults() {
        let suite = "local.statstrio.tests.\(UUID().uuidString)"
        let destination = UserDefaults(suiteName: suite)!
        defer { destination.removePersistentDomain(forName: suite) }
        _ = PreferenceMigration.migrate(source: ["CPU_updateInterval": -1, "RAM_widget": 42,
                                                "Sensors_hid": "yes"], destination: destination)
        XCTAssertEqual(destination.integer(forKey: "CPU_updateInterval"), 2)
        XCTAssertEqual(destination.string(forKey: "RAM_widget"), "mini")
        XCTAssertEqual(destination.string(forKey: "Network_widget"), "speed")
        XCTAssertTrue(destination.bool(forKey: "sensor_Hottest CPU"))
        XCTAssertTrue(destination.bool(forKey: "sensor_PSTR"))
        XCTAssertTrue(destination.bool(forKey: "Sensors_hid"))
        XCTAssertNil(destination.object(forKey: "launchAtLogin"))
    }
}

final class CompactAppearanceTests: XCTestCase {
    func testExistingInstallReceivesCompactDefaultsOnlyOnce() {
        let name = "StatsTrioCompactTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(1, forKey: "StatsTrioMigrationVersion")
        defaults.set(3, forKey: "RAM_updateInterval")
        CompactAppearanceMigration.apply(to: defaults)
        XCTAssertEqual(defaults.string(forKey: "Network_speed_icon"), "none")
        XCTAssertEqual(defaults.string(forKey: "CombinedModules_spacing"), "4")
        XCTAssertEqual(defaults.integer(forKey: "RAM_updateInterval"), 3)
        defaults.set("2", forKey: "CombinedModules_spacing")
        CompactAppearanceMigration.apply(to: defaults)
        XCTAssertEqual(defaults.string(forKey: "CombinedModules_spacing"), "2")
    }
}
