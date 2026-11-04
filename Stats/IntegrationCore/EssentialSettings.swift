import Foundation
import Combine

public enum LoginItemState: Equatable { case disabled, enabled, requiresApproval }
@MainActor public protocol LoginItemRegistering {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
}
public struct InterfaceResolution {
    public let id: String?
    public let didFallback: Bool
}

@MainActor
public final class EssentialSettings: ObservableObject {
    private let defaults: UserDefaults
    private let login: any LoginItemRegistering
    private let onWrite: (String, Any) -> Void
    private let moduleChanged: (ModuleID, Bool) -> Void
    @Published public private(set) var revision = 0

    public init(defaults: UserDefaults, login: any LoginItemRegistering,
                onWrite: @escaping (String, Any) -> Void = { _, _ in },
                moduleChanged: @escaping (ModuleID, Bool) -> Void = { _, _ in }) {
        self.defaults = defaults
        self.login = login
        self.onWrite = onWrite
        self.moduleChanged = moduleChanged
    }
    public var moduleOrder: [ModuleID] {
        ModuleID.allCases.enumerated().sorted {
            let a = defaults.object(forKey: "\($0.element.rawValue)_position") as? Int ?? $0.offset
            let b = defaults.object(forKey: "\($1.element.rawValue)_position") as? Int ?? $1.offset
            return a == b ? $0.offset < $1.offset : a < b
        }.map(\.element)
    }
    public func isEnabled(_ id: ModuleID) -> Bool { bool("\(id.rawValue)_state", fallback: true) }
    public func setModule(_ id: ModuleID, enabled: Bool) {
        write("\(id.rawValue)_state", enabled)
        moduleChanged(id, enabled)
    }
    public func refreshInterval(for id: ModuleID) -> Int {
        integer("\(id.rawValue)_updateInterval", fallback: id == .sensors ? 3 : id == .network ? 1 : 2)
    }
    public func setRefreshInterval(_ value: Int, for id: ModuleID) {
        guard (1...60).contains(value) else { return }
        write("\(id.rawValue)_updateInterval", value)
    }
    public func bool(_ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }
    public func integer(_ key: String, fallback: Int) -> Int {
        defaults.object(forKey: key) as? Int ?? fallback
    }
    public func string(_ key: String, fallback: String = "") -> String {
        defaults.string(forKey: key) ?? fallback
    }
    public func setBool(_ value: Bool, for key: String) { write(key, value) }
    public func setString(_ value: String, for key: String) { write(key, value) }
    public func setInteger(_ value: Int, for key: String) { write(key, value) }
    public func moveModule(_ id: ModuleID, by offset: Int) {
        var order = moduleOrder
        guard let source = order.firstIndex(of: id) else { return }
        let target = source + offset
        guard order.indices.contains(target) else { return }
        order.swapAt(source, target)
        for (index, item) in order.enumerated() { write("\(item.rawValue)_position", index) }
    }
    public func resolveInterface(available: [String], primary: String?) -> InterfaceResolution {
        let current = string("Network_interface")
        let automatic = primary.flatMap { available.contains($0) ? $0 : nil } ?? available.first
        guard !current.isEmpty else { return InterfaceResolution(id: automatic, didFallback: false) }
        if available.contains(current) { return InterfaceResolution(id: current, didFallback: false) }
        write("Network_interface", "")
        return InterfaceResolution(id: automatic, didFallback: true)
    }
    public var loginState: LoginItemState { login.state }
    public func setLaunchAtLogin(_ enabled: Bool) throws {
        defer { revision += 1 }
        if (enabled && login.state == .enabled) || (!enabled && login.state == .disabled) { return }
        try login.setEnabled(enabled)
    }
    public func refreshState() { revision += 1 }
    private func write(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        onWrite(key, value)
        revision += 1
    }
}
