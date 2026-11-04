import AppKit
import Kit
import CPU
import RAM
import Net
import Sensors
import SwiftUI
import SystemConfiguration

var modules: [Module] = []

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PanelCoordinator()
    private var combined: CombinedView?
    private var trio: TrioBridge?
    private var settingsObserver: NSObjectProtocol?
    private var settingsWindow: NSWindow?
    private var settingsModel: EssentialSettings?
    static func main() {
        let app = NSApplication.shared
        if ProcessInfo.processInfo.environment["STATS_TRIO_TESTING"] != "1" {
            let source = UserDefaults.standard.persistentDomain(forName: "eu.exelban.Stats") ?? [:]
            _ = PreferenceMigration.migrate(source: source, destination: .standard)
            CompactAppearanceMigration.apply(to: .standard)
        }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["STATS_TRIO_TESTING"] == "1" { return }
        installMainMenu()
        modules = [CPU(), RAM(), Sensors(), Network()]
        let trio = TrioBridge(defaults: .standard)
        self.trio = trio
        for module in modules {
            if let id = CombinedView.id(for: module.name) {
                coordinator.register(StatsPanelAdapter(module), for: id)
            }
        }
        coordinator.register(trio, for: .trio)
        let combined = CombinedView(modules: modules, coordinator: coordinator, trio: trio)
        self.combined = combined
        combined.openSettings = { [weak self] in self?.showSettings() }
        trio.openSettings = { [weak self] in self?.showSettings() }
        settingsObserver = NotificationCenter.default.addObserver(forName: .toggleSettings, object: nil, queue: .main) { [weak self] _ in DispatchQueue.main.async { self?.showSettings() } }
        modules.forEach { $0.mount() }
        combined.recalculate()
        trio.runtime.start()
        if !UserDefaults.standard.bool(forKey: "StatsTrioHasOpenedSettings") {
            UserDefaults.standard.set(true, forKey: "StatsTrioHasOpenedSettings")
            showSettings()
        }
    }
    private func installMainMenu() {
        let root = NSMenu()
        let application = NSMenuItem(title: "Stats Trio", action: nil, keyEquivalent: "")
        root.addItem(application)
        let app = NSMenu(title: "Stats Trio")
        app.addItem(withTitle: "关于 Stats Trio", action: #selector(showAbout), keyEquivalent: "").target = self
        app.addItem(withTitle: "设置…", action: #selector(openSettingsMenu), keyEquivalent: ",").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "退出 Stats Trio", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        application.submenu = app
        let panels = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windows = NSMenu(title: "窗口")
        for (id, title) in [(PanelID.cpu, "CPU 详情"), (.memory, "内存详情"), (.sensors, "温度／功率详情"), (.network, "网速详情"), (.trio, "Trio 面板")] {
            let item = NSMenuItem(title: title, action: #selector(openPanelMenu(_:)), keyEquivalent: "")
            item.representedObject = id.rawValue
            item.target = self
            windows.addItem(item)
        }
        panels.submenu = windows
        root.addItem(panels)
        NSApp.mainMenu = root
    }
    @objc private func openSettingsMenu() { showSettings() }
    @objc private func showAbout() { coordinator.dismissAll(); NSApp.orderFrontStandardAboutPanel(nil) }
    @objc private func openPanelMenu(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let id = PanelID(rawValue: raw) else { return }
        combined?.toggle(id)
    }
    private func showSettings() {
        coordinator.dismissAll()
        let model = EssentialSettings(defaults: .standard, login: NativeLoginRegistrar(),
            onWrite: { [weak self] key, value in self?.writeSetting(key, value) },
            moduleChanged: { [weak self] id, enabled in
                self?.coordinator.dismissAll()
                guard let module = modules.first(where: { $0.name == id.rawValue }) else { return }
                if enabled { module.enable() } else { module.disable() }
                self?.combined?.recalculate()
            })
        settingsModel = model
        let interfaces = (SCNetworkInterfaceCopyAll() as NSArray).compactMap { raw -> InterfaceOption? in
            let interface = raw as! SCNetworkInterface
            guard let id = SCNetworkInterfaceGetBSDName(interface) as String? else { return nil }
            let label = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? ?? id
            return InterfaceOption(id: id, title: "\(label)（\(id)）")
        }.reduce(into: [InterfaceOption]()) { values, option in
            if !values.contains(where: { $0.id == option.id }) { values.append(option) }
        }
        let primary = (SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any])?["PrimaryInterface"] as? String
        let resolved = model.resolveInterface(available: interfaces.map(\.id), primary: primary)
        let view = EssentialSettingsView(model: model, interfaces: interfaces,
            sensors: {
                (modules.compactMap { $0 as? Sensors }.first?.selectableSensors ?? []).map {
                    SensorOption(id: $0.key, title: $0.key == "Hottest CPU" ? "CPU 最高温度" : $0.key == "PSTR" ? "系统总功率" : $0.name)
                }
            }, fallbackMessage: resolved.didFallback ? "原网卡不可用，已回退自动选择。" : nil)
        let isNewWindow = settingsWindow == nil
        let window = settingsWindow ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Stats Trio 设置"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        if isNewWindow { window.center() }
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    private func writeSetting(_ key: String, _ value: Any) {
        if let value = value as? Bool { Store.shared.set(key: key, value: value) }
        else if let value = value as? Int { Store.shared.set(key: key, value: value) }
        else if let value = value as? String { Store.shared.set(key: key, value: value) }
        if key.hasSuffix("_position") || key == "CombinedModules_spacing" { combined?.recalculate(); return }
        if key.hasPrefix("StatsTrio_") { trio?.runtime.applyFunctionalSettings(defaults: .standard); return }
        if key.hasSuffix("_state") { return }
        modules.filter { key.hasPrefix($0.name + "_") || ($0.name == "Sensors" && key.hasPrefix("sensor_")) }
            .forEach { $0.settingsDidChange(key) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationDidBecomeActive(_ notification: Notification) { settingsModel?.refreshState() }
    func applicationWillTerminate(_ notification: Notification) {
        combined?.stop()
        trio?.runtime.stop()
        modules.forEach { $0.terminate() }
        if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
    }
}
