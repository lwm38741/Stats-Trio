import AppKit
import Foundation
import CoreAudio
@testable import TrioEmbedded

@MainActor
class StreamMonitor<Value: Sendable> {
    let updates: AsyncStream<Value>
    let continuation: AsyncStream<Value>.Continuation
    let value: Value
    var starts = 0
    var stops = 0
    var recoveries = 0
    init(_ value: Value) {
        let pair = AsyncStream<Value>.makeStream()
        updates = pair.stream
        continuation = pair.continuation
        self.value = value
    }
    func start() { starts += 1; continuation.yield(value) }
    func refresh() { continuation.yield(value) }
    func recover() { recoveries += 1 }
    func stop() { stops += 1; continuation.finish() }
}
@MainActor final class Battery: StreamMonitor<BatteryStatus>, BatteryMonitoring {}
@MainActor final class WiFi: StreamMonitor<WiFiStatus>, WiFiMonitoring {
    var detailsVisible = false
    func setDetailsVisible(_ visible: Bool) { detailsVisible = visible }
    func requestNameAccess() -> WiFiNameAccessRequestResult { .openLocationSettings }
}
@MainActor final class Volume: StreamMonitor<VolumeStatus>, VolumeMonitoring, VolumeControlling {
    var detailsVisible = false
    var acceptsWrites = false
    func setDetailsVisible(_ visible: Bool) { detailsVisible = visible }
    func setVolume(_ scalar: Double) -> Bool { acceptsWrites }
    func toggleMute() -> Bool { acceptsWrites }
    func selectOutputDevice(_ id: AudioDeviceID) -> Bool { acceptsWrites }
}
@MainActor final class Brightness: StreamMonitor<BrightnessStatus>, BrightnessMonitoring {}
@MainActor final class DeniedBluetooth: BluetoothStateMonitoring {
    var onStateChange: ((BluetoothAuthorizationStatus, BluetoothManagerState) -> Void)?
    var authorization: BluetoothAuthorizationStatus { .denied }
    func start() {}
    func stop() {}
}

@MainActor final class RejectedOutput: AudioOutputControlling {
    func setVolume(_ value: Double) -> Bool { false }
    func toggleMute() -> Bool { false }
    func selectOutputDevice(_ id: AudioDeviceID) -> Bool { false }
}
@MainActor final class AudioReader: AudioStatusReadingProviding {
    func read(includeOutputDevices: Bool, completion: @escaping @MainActor @Sendable (AudioStatusReading) -> Void) {
        completion(AudioStatusReading(volume: VolumeReading(scalar: 0.4, isMuted: false,
            deviceName: "Fake", currentDevice: AudioOutputDevice(id: 1, name: "Fake", isCurrent: true)),
            outputDevices: []))
    }
}
@MainActor final class AudioEvents: VolumeEventMonitoring {
    func start(onDefaultDeviceChange: @escaping @MainActor @Sendable () -> Void,
               onVolumeChange: @escaping @MainActor @Sendable () -> Void) {}
    func reconcile() {}
    func recover() {}
    func stop() {}
}

Task { @MainActor in
    let networkLocalization = Localization()
    let connectedWiFi = WiFiStatus(state: .connected, rssi: -29, ssid: "Office_Test_5G", nameAccess: .authorized, band: .fiveGHz)
    let baseWiFi = PanelPresentationMapper.network(wifi: connectedWiFi, connection: .wifi, wired: nil,
        isConstrained: false, isResolvingName: false, localization: networkLocalization)
    let summary = EmbeddedNetworkSummary.make(base: baseWiFi, wifi: connectedWiFi, connection: .wifi,
        hardware: TrioSummaryHardware(adapterWatts: 30, linkMbps: 960), localization: networkLocalization)
    precondition(summary.title == networkLocalization.string(.wifiTitle) + " · Office_Test_5G")
    precondition(!summary.subtitle.contains(networkLocalization.string(.wifiSubtitleConnected)))
    precondition(summary.subtitle.contains("-29") && summary.subtitle.contains("5"))
    precondition(!summary.subtitle.contains("\n") && summary.subtitle.hasSuffix("握手速率 · 960 Mbps"))
    let deniedName = WiFiStatus(state: .connected, rssi: -50, ssid: "Stale_Test", nameAccess: .denied)
    let deniedSummary = EmbeddedNetworkSummary.make(base: baseWiFi, wifi: deniedName, connection: .wifi,
        hardware: nil, localization: networkLocalization)
    precondition(deniedSummary.title == networkLocalization.string(.wifiTitle))
    precondition(!deniedSummary.accessibilityLabel.contains("Stale_Test"))
    print("Wi-Fi summary title, no redundant connected label, full rate and denied-name privacy: PASS")
    // Literal presentation requirements for the compact user-approved style.
    let fullBattery = BatteryStatus(rawPercentage: 100, isPresent: true, isCharging: false, isLowPowerMode: false, isConnectedToPower: true)
    let fullScene = CompactBatteryPresentation.scene(battery: fullBattery)
    precondition(fullScene.outerRing!.gap == .closed && fullScene.outerRing!.accessory == nil)
    precondition(fullScene.outerRing!.segments.first?.progress == 1)
    let chargingBattery = BatteryStatus(rawPercentage: 50, isPresent: true, isCharging: true, isLowPowerMode: false, isConnectedToPower: true)
    let chargingScene = CompactBatteryPresentation.scene(battery: chargingBattery)
    precondition(chargingScene.outerRing!.gap == .indicator && chargingScene.outerRing!.accessory != nil)
    precondition(TrioSummaryHardware.mediaMbps("1000baseT") == 1000)
    precondition(TrioSummaryHardware.mediaMbps("10Gbase-T") == 10000)
    precondition(TrioSummaryHardware.mediaMbps("autoselect") == nil)
    precondition(TrioSummaryHardware(adapterWatts: 30, linkMbps: 1000).adapterText == "电源适配器 · 30 W")
    precondition(TrioSummaryHardware(adapterWatts: nil, linkMbps: nil).linkText == "握手速率不可用")
    let unplugged = BatteryStatus(rawPercentage: 80, isPresent: true, isCharging: false, isLowPowerMode: false, isConnectedToPower: false)
    precondition(CompactBatteryPresentation.scene(battery: unplugged).outerRing!.accessory == nil)
    precondition(TrioSummaryHardware.mediaMbps("2500baseT") == 2500)
    let sceneImage = StatusIconRenderer.menuBarImage(scene: fullScene, size: 64, scale: 2, appearance: NSAppearance(named: .darkAqua)!)!
    if let data = sceneImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data),
       let png = bitmap.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "build/compact-battery-full.png"))
    }
    print("Compact battery full/charging/unplugged and link metadata: PASS")
    let disabledBrightness = DisabledBrightnessMonitor()
    disabledBrightness.start()
    disabledBrightness.refresh()
    disabledBrightness.stop()
    var brightnessEvents = disabledBrightness.updates.makeAsyncIterator()
    let disabledEvent = await brightnessEvents.next()
    let battery = Battery(BatteryStatus(rawPercentage: 42, isPresent: true, isCharging: false,
                                         isLowPowerMode: false, isConnectedToPower: false))
    let wifi = WiFi(WiFiStatus(state: .connected, rssi: -60, nameAccess: .denied))
    let volume = Volume(VolumeStatus(scalar: nil, isMuted: false, deviceName: nil))
    let brightness = Brightness(.placeholder)
    let bluetooth = BluetoothDeviceController(stateMonitor: DeniedBluetooth())
    let wakeCenter = NotificationCenter()
    bluetooth.prepareForPresentation()
    let store = SystemStatusStore(batteryMonitor: battery, wifiMonitor: wifi,
                                  volumeMonitor: volume, brightnessMonitor: brightness,
                                  volumeFeedback: nil, refreshInterval: .seconds(60),
                                  wakeNotificationCenter: wakeCenter,
                                  bluetoothDevices: bluetooth)
    let panelDefaultsName = "StatsTrioSummaryTest-" + UUID().uuidString
    let panelDefaults = UserDefaults(suiteName: panelDefaultsName)!
    let panelSettings = SettingsStore(defaults: panelDefaults)
    let presentation = StatusPanelViewModel(store: store, settings: panelSettings, localization: Localization(),
        actions: StatusPanelActions(store: store, settings: panelSettings))
    store.setPopoverVisible(true)
    presentation.startSummaryHardwareUpdates()
    presentation.stopSummaryHardwareUpdates()
    try? await Task.sleep(for: .milliseconds(100))
    precondition(presentation.summaryHardware == nil, "late metadata updated a dismissed panel")
    panelDefaults.removePersistentDomain(forName: panelDefaultsName)
    store.setPopoverVisible(false)
    store.start()
    store.start()
    try? await Task.sleep(for: .milliseconds(300))
    // Authorization is surfaced when the panel prepares; hidden inactive lists reset to idle.
    bluetooth.prepareForPresentation()
    var problems: [String] = []
    var interactionWrites = 0
    let interactionID = VolumeControlInteractionIdentity(output: nil, configuration: .default)
    var interaction = VolumeControlInteraction(setVolume: { _ in interactionWrites += 1 }, finishVolume: {})
    interaction.receiveSystemState(identity: interactionID, scalar: 0.4, canAdjust: true)
    interaction.beginEditing()
    interaction.setSliderValue(0.9, identity: interactionID, canAdjust: true)
    interaction.receiveSystemState(identity: interactionID, scalar: 0.4, canAdjust: false)
    interaction.receiveSystemState(identity: interactionID, scalar: 0.4, canAdjust: true)
    if interaction.value != 0.4 || interaction.isEditing || interactionWrites != 1 {
        problems.append("rejected slider draft did not restore actual value")
    }
    let nativeVolume = VolumeMonitor(statusReader: AudioReader(), eventMonitor: AudioEvents(), outputController: RejectedOutput())
    nativeVolume.start()
    try? await Task.sleep(for: .milliseconds(100))
    if nativeVolume.setVolume(0.9) || nativeVolume.toggleMute() || nativeVolume.selectOutputDevice(99) {
        problems.append("native monitor dropped rejected CoreAudio results")
    }
    nativeVolume.stop()
    if disabledEvent != nil { problems.append("excluded brightness produced monitoring data") }
    if store.snapshot.battery.percentage != 42 { problems.append("denied Wi-Fi blocked battery updates") }
    if store.snapshot.wifi.nameAccess != .denied { problems.append("denied Wi-Fi authorization was not preserved") }
    if store.snapshot.volume.canSetVolume { problems.append("missing output incorrectly enables volume control") }
    if bluetooth.availability != .authorizationDenied { problems.append("denied Bluetooth was not preserved") }
    if battery.starts != 1 || wifi.starts != 1 || volume.starts != 1 { problems.append("duplicate monitor startup") }
    var selected = false
    let actions = StatusPanelActions(outputDevices: { [] }, selectOutput: { _ in selected = true })
    actions.selectOutput(PanelAudioDeviceID(id: 99, uid: "disappeared"))
    if selected { problems.append("disappeared output was selected") }
    for _ in 0..<20 {
        store.setPopoverVisible(true)
        store.setPopoverVisible(false)
    }
    if wifi.detailsVisible || volume.detailsVisible { problems.append("hidden panel retained detail demand") }
    if battery.starts != 1 || wifi.starts != 1 { problems.append("visibility cycles duplicated base monitors") }
    wakeCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    try? await Task.sleep(for: .milliseconds(100))
    let recoveries = wifi.recoveries
    if recoveries == 0 { problems.append("injected wake did not recover monitor") }
    // A rejected native write must keep measured state and present an error.
    volume.continuation.yield(VolumeStatus(scalar: 0.4, isMuted: false, deviceName: "Fake"))
    try? await Task.sleep(for: .milliseconds(100))
    store.setVolume(0.9)
    if store.liveVolume.scalar != 0.4 || store.volumeActionError == nil { problems.append("failed volume write was displayed as success") }
    store.selectOutputDevice(AudioOutputDevice(id: 99, name: "Gone", isCurrent: false))
    if store.volumeActionError == nil || store.liveVolume.scalar != 0.4 { problems.append("failed selection lacked error or lost actual state") }
    store.toggleMute()
    if store.liveVolume.isMuted || store.volumeActionError == nil { problems.append("failed mute was displayed as success") }
    volume.acceptsWrites = true
    store.setVolume(0.6)
    if store.liveVolume.scalar != 0.6 || store.volumeActionError != nil { problems.append("successful retry failed to clear transient error") }
    store.stop()
    store.stop()
    wakeCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    try? await Task.sleep(for: .milliseconds(100))
    if wifi.recoveries != recoveries { problems.append("stopped monitor still handled wake") }
    if battery.stops != 1 || wifi.stops != 1 || volume.stops != 1 { problems.append("monitor teardown not idempotent") }
    for problem in problems { print("FAIL: \(problem)") }
    print("Embedded upstream characterization: \(problems.isEmpty ? "PASS" : "FAIL")")
    exit(problems.isEmpty ? 0 : 1)
}
RunLoop.main.run()
