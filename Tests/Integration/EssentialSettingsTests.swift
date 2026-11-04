import Foundation

@MainActor
final class TestLoginRegistrar: LoginItemRegistering {
    var state: LoginItemState = .disabled
    var requests: [Bool] = []
    var fail = false
    func setEnabled(_ enabled: Bool) throws {
        requests.append(enabled)
        if fail { throw NSError(domain: "test", code: 1) }
        state = enabled ? .requiresApproval : .disabled
    }
}

@MainActor
final class EssentialSettingsTests: XCTestCase {
    func testOnlySupportedModulesAndExplicitLoginRegistration() {
        let suite = "local.statstrio.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let registrar = TestLoginRegistrar()
        var changes: [ModuleID: Bool] = [:]
        let model = EssentialSettings(defaults: defaults, login: registrar,
                                      moduleChanged: { changes[$0] = $1 })
        XCTAssertEqual(model.moduleOrder, [.cpu, .memory, .sensors, .network])
        XCTAssertEqual(registrar.requests, [])
        model.setModule(.cpu, enabled: false)
        XCTAssertEqual(changes[.cpu], false)
        XCTAssertFalse(defaults.bool(forKey: "CPU_state"))
        model.setRefreshInterval(5, for: .memory)
        XCTAssertEqual(defaults.integer(forKey: "RAM_updateInterval"), 5)
        let reopened = EssentialSettings(defaults: defaults, login: registrar)
        XCTAssertEqual(reopened.refreshInterval(for: .memory), 5)
        do { try model.setLaunchAtLogin(true) } catch { XCTAssertTrue(false) }
        XCTAssertEqual(registrar.requests, [true])
        XCTAssertEqual(model.loginState, .requiresApproval)
        registrar.fail = true
        do { try model.setLaunchAtLogin(false); XCTAssertTrue(false) } catch {}
        XCTAssertEqual(model.loginState, .requiresApproval)
    }
    func testMissingInterfaceFallsBackAndReorderingPersists() {
        let suite = "local.statstrio.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("missing0", forKey: "Network_interface")
        let model = EssentialSettings(defaults: defaults, login: TestLoginRegistrar())
        let resolution = model.resolveInterface(available: ["en0", "en5"], primary: "en0")
        XCTAssertEqual(resolution.id, "en0")
        XCTAssertTrue(resolution.didFallback)
        XCTAssertEqual(defaults.string(forKey: "Network_interface"), "")
        model.moveModule(.network, by: -1)
        XCTAssertEqual(model.moduleOrder, [.cpu, .memory, .network, .sensors])
        model.setRefreshInterval(0, for: .cpu)
        XCTAssertEqual(model.refreshInterval(for: .cpu), 2)
    }
}
