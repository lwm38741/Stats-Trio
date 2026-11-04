import SwiftUI
import ServiceManagement

struct SensorOption: Identifiable {
    let id: String
    let title: String
}
struct InterfaceOption: Identifiable {
    let id: String
    let title: String
}

@MainActor
struct EssentialSettingsView: View {
    @ObservedObject var model: EssentialSettings
    let interfaces: [InterfaceOption]
    let sensors: () -> [SensorOption]
    let fallbackMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text("组合显示，分别点开详情")
                    .font(.headline)
                Text("点击 Trio 图标打开电池、网络、蓝牙和声音面板。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("监测项目") {
                ForEach(model.moduleOrder, id: \.self) { module in
                    HStack {
                        Toggle(module.title, isOn: Binding(
                            get: { model.isEnabled(module) },
                            set: { model.setModule(module, enabled: $0) }))
                        Spacer()
                        Stepper("\(model.refreshInterval(for: module)) 秒", value: Binding(
                            get: { model.refreshInterval(for: module) },
                            set: { model.setRefreshInterval($0, for: module) }), in: 1...60)
                            .frame(width: 115).disabled(!model.isEnabled(module))
                        Button { model.moveModule(module, by: -1) } label: { Image(systemName: "chevron.up") }
                            .help("向前移动").disabled(model.moduleOrder.first == module)
                        Button { model.moveModule(module, by: 1) } label: { Image(systemName: "chevron.down") }
                            .help("向后移动").disabled(model.moduleOrder.last == module)
                    }
                }
                Picker("图标间距", selection: stringBinding("CombinedModules_spacing", fallback: "2")) {
                    ForEach(["0", "2", "4", "6"], id: \.self) { Text("\($0) 点").tag($0) }
                }
            }
            Section("网络与传感器") {
                Picker("网速统计网卡", selection: stringBinding("Network_interface")) {
                    Text("自动选择").tag("")
                    ForEach(interfaces) { Text($0.title).tag($0.id) }
                }
                if let fallbackMessage { Text(fallbackMessage).font(.caption).foregroundStyle(.secondary) }
                Menu("选择菜单栏传感器") {
                    ForEach(sensors()) { option in
                        Toggle(option.title, isOn: boolBinding("sensor_\(option.id)", fallback: false))
                    }
                }
                Text("默认项目：CPU 最高温度、系统总功率。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("详情与 Trio") {
                Stepper("CPU 详情进程数：\(model.integer("CPU_processes", fallback: 10))",
                        value: integerBinding("CPU_processes", fallback: 10), in: 0...20)
                Stepper("内存详情进程数：\(model.integer("RAM_processes", fallback: 10))",
                        value: integerBinding("RAM_processes", fallback: 10), in: 0...20)
                Toggle("显示蓝牙设备", isOn: boolBinding("StatsTrio_showBluetooth", fallback: true))
                Toggle("显示蓝牙设备电量", isOn: boolBinding("StatsTrio_showBluetoothBattery", fallback: true))
                Toggle("显示输入法", isOn: boolBinding("StatsTrio_showInputSource", fallback: true))
            }
            Section("启动") {
                Toggle("开机启动", isOn: Binding(
                    get: { model.loginState == .enabled },
                    set: { value in
                        do { try model.setLaunchAtLogin(value); errorMessage = nil }
                        catch { errorMessage = error.localizedDescription }
                    }))
                if model.loginState == .requiresApproval {
                    HStack {
                        Text("等待系统批准登录项").foregroundStyle(.secondary)
                        Spacer()
                        Button("打开登录项设置") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 620)
    }
    private func boolBinding(_ key: String, fallback: Bool) -> Binding<Bool> {
        Binding(get: { model.bool(key, fallback: fallback) }, set: { model.setBool($0, for: key) })
    }
    private func stringBinding(_ key: String, fallback: String = "") -> Binding<String> {
        Binding(get: { model.string(key, fallback: fallback) }, set: { model.setString($0, for: key) })
    }
    private func integerBinding(_ key: String, fallback: Int) -> Binding<Int> {
        Binding(get: { model.integer(key, fallback: fallback) }, set: { model.setInteger($0, for: key) })
    }
}

private extension ModuleID {
    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "内存"
        case .sensors: return "温度／功率"
        case .network: return "网速"
        }
    }
}
