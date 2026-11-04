import AppKit
import Combine
import SwiftUI

@MainActor
public final class TrioEmbeddedRuntime {
    private let store: SystemStatusStore
    private let settings: SettingsStore
    private let localization: Localization
    private let inputSource: InputSourceController
    private let panel: StatusPanelViewModel
    private let panelWindow = AnchoredStatusPanel()
    public var onPanelDismiss: (() -> Void)?
    public var isPanelVisible: Bool { panelWindow.isShown }
    public var panelWindowNumber: Int { panelWindow.windowNumber }
    private var observation: AnyCancellable?
    public var onIconChanged: (() -> Void)?

    private lazy var lifecycle = TrioRuntimeLifecycle(
        start: { [weak self] in
            guard let self else { return }
            self.panel.start()
            self.inputSource.start()
            self.observation = self.store.$snapshot.dropFirst().sink { [weak self] _ in self?.onIconChanged?() }
            self.store.start()
        },
        stop: { [weak self] in
            self?.observation = nil
            self?.panel.stopSummaryHardwareUpdates()
            self?.panel.stop()
            self?.inputSource.stop()
            self?.store.stop()
        },
        visibility: { [weak self] visible in
            guard let self else { return }
            self.store.setPopoverVisible(visible)
            if visible {
                self.panel.startSummaryHardwareUpdates()
                self.panel.prepareForPresentation()
            }
            else {
                self.panel.stopSummaryHardwareUpdates()
                self.panel.showSummaryPage()
                self.panel.releaseInactivePresentationState()
            }
        })

    public init(defaults: UserDefaults) {
        settings = SettingsStore(defaults: defaults)
        let wanted: Set<PopupSection> = [.battery, .network, .bluetooth, .volume, .inputSource]
        for section in PopupSection.allCases { settings.setPopupSection(section, enabled: wanted.contains(section)) }
        settings.controlsLowPowerMode = false
        settings.showsBluetoothDeviceList = defaults.object(forKey: "StatsTrio_showBluetooth") as? Bool ?? true
        settings.showsBluetoothBatteryLevels = defaults.object(forKey: "StatsTrio_showBluetoothBattery") as? Bool ?? true
        settings.showsBatteryPowerFlow = false
        settings.setPopupSection(.bluetooth, enabled: settings.showsBluetoothDeviceList)
        settings.setPopupSection(.inputSource, enabled: defaults.object(forKey: "StatsTrio_showInputSource") as? Bool ?? true)
        store = SystemStatusStore(
            batteryMonitor: BatteryMonitor(), wifiMonitor: WiFiMonitor(),
            connectionMonitor: NetworkConnectionMonitor(),
            volumeMonitor: VolumeMonitor(outputController: CoreAudioOutputController()),
            brightnessMonitor: DisabledBrightnessMonitor(),
            inputMonitor: AudioInputMonitor(hardware: CoreAudioInputHardware()),
            refreshInterval: .seconds(15),
            bluetoothDevices: BluetoothDeviceController(
                accessoryBatteryReader: PmsetAccessoryBatteryWorker(),
                connectionEvents: IOBluetoothConnectionEventMonitor(),
                accessoryBatteryEvents: AccessoryPowerNotifyEventMonitor(),
                nearbyBatteryScanner: CoreBluetoothLEBatteryScanner()))
        localization = Localization()
        inputSource = InputSourceController()
        let actions = StatusPanelActions(store: store, settings: settings, inputSourceController: inputSource)
        panel = StatusPanelViewModel(store: store, settings: settings, localization: localization,
                                   actions: actions, inputSourceController: inputSource)
        store.bindBluetoothSettings(settings)
        store.bindExternalVolumeSettings(settings)
        store.bindInputSettings(settings)
    }

    public func applyFunctionalSettings(defaults: UserDefaults) {
        settings.showsBluetoothDeviceList = defaults.object(forKey: "StatsTrio_showBluetooth") as? Bool ?? true
        settings.showsBluetoothBatteryLevels = defaults.object(forKey: "StatsTrio_showBluetoothBattery") as? Bool ?? true
        settings.setPopupSection(.bluetooth, enabled: settings.showsBluetoothDeviceList)
        settings.setPopupSection(.inputSource, enabled: defaults.object(forKey: "StatsTrio_showInputSource") as? Bool ?? true)
    }
    public func start() { lifecycle.start() }
    public func stop() { lifecycle.stop() }
    public func setPanelVisible(_ visible: Bool) { lifecycle.setPanelVisible(visible) }
    public func setMaximumPanelHeight(_ height: CGFloat) { panelWindow.layoutMetrics.update(maximumPanelHeight: height) }

    public func renderIcon(size: CGFloat, scale: CGFloat, appearance: NSAppearance) -> NSImage {
        let appearanceSettings = StatusIconAppearance(settings: settings)
        let config = IconPresentationConfiguration(battery: CompactBatteryPresentation.options(for: store.snapshot.battery),
                                                  connection: appearanceSettings.connectionOptions,
                                                  volume: appearanceSettings.volumeOptions,
                                                  bluetooth: appearanceSettings.bluetoothAudioOptions)
        let inputs = IconPresentationResourceResolver.inputs(snapshot: store.snapshot)
        let scene = IconPresentationMapper.scene(inputs: inputs, configuration: config)
        return StatusIconRenderer.menuBarImage(scene: scene, size: size, scale: scale, appearance: appearance)
            ?? NSImage(size: NSSize(width: size, height: size))
    }

    public func makePanelController(openSettings: @escaping () -> Void,
                                    dismiss: @escaping () -> Void) -> NSViewController {
        let root = LocalizedRootView(localization: localization) {
            StatusPopoverView(panel: panel, scrollTargets: PopoverScrollTargets(), layoutMetrics: panelWindow.layoutMetrics,
                requestWiFiNameAccess: { _ = self.store.requestWiFiNameAccess() },
                requestBluetoothAuthorization: { self.store.requestBluetoothAuthorization() },
                openBatterySettings: { self.open("Battery-Settings.extension") },
                openAppBatterySettings: openSettings,
                openWiFiSettings: { self.open("wifi-settings-extension") },
                openNetworkSettings: { self.open("Network-Settings.extension") },
                openSharingSettings: { self.open("Sharing-Settings.extension") },
                openLocationSettings: { self.open("preference.security?Privacy_LocationServices") },
                openBluetoothSettings: { self.open("BluetoothSettings") },
                openBluetoothPermissionSettings: { self.open("preference.security?Privacy_Bluetooth") },
                openSettings: openSettings,
                openSoundSettings: { self.open("Sound-Settings.extension?output") },
                openSoundInputSettings: { self.open("Sound-Settings.extension?input") },
                openKeyboardSettings: { self.open("Keyboard-Settings.extension") },
                quit: { NSApp.terminate(nil) }, dismissPanel: dismiss)
        }
        let controller = StatusPanelHostingController(rootView: root)
        controller.sizingOptions = [.preferredContentSize]
        panelWindow.installContent(controller, backgroundStyle: settings.panelBackgroundStyle)
        panelWindow.title = "Trio"
        panelWindow.onClose = { [weak self] in
            self?.setPanelVisible(false)
            self?.onPanelDismiss?()
        }
        return controller
    }

    public func showPanel(relativeTo rect: NSRect, of view: NSView) {
        setPanelVisible(true)
        panelWindow.show(relativeTo: rect, of: view, preferredEdge: .minY)
        panelWindow.makeKey()
    }
    public func dismissPanel() { panelWindow.performClose(nil) }
    public func updatePanelAnchor(of view: NSView) {
        panelWindow.updateAnchor(relativeTo: view.bounds, of: view)
    }

    private func open(_ pane: String) {
        dismissPanel()
        if let url = URL(string: "x-apple.systempreferences:com.apple.\(pane)") { NSWorkspace.shared.open(url) }
    }
}
