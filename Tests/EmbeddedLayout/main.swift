import AppKit
import SwiftUI
@testable import TrioEmbedded

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let localization = Localization()
    let wifi = WiFiStatus(state: .connected, rssi: -29, ssid: "Office_Test_5G", nameAccess: .authorized, band: .fiveGHz)
    let base = PanelPresentationMapper.network(wifi: wifi, connection: .wifi, wired: nil,
        isConstrained: false, isResolvingName: false, localization: localization)
    let state = EmbeddedNetworkSummary.make(base: base, wifi: wifi, connection: .wifi,
        hardware: TrioSummaryHardware(adapterWatts: 30, linkMbps: 960), localization: localization)
    let row = NetworkStatusView(state: state, onOpenWiFiDetails: { _ in }, onOpenWiredDetails: {},
        onRequestNameAccess: {}, onOpenWiFiSettings: {}, onOpenNetworkSettings: {}, onOpenLocationSettings: {})
        .environmentObject(localization).frame(width: 302, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    let hosting = NSHostingView(rootView: row)
    let size = hosting.fittingSize
    print("Real Wi-Fi summary row size: \(size)")
    guard size.height <= 40, !state.subtitle.contains("\n") else { print("FAIL: link facts should share one complete line"); exit(1) }
    let longNameState = PanelSummaryState(title: "Wi-Fi · " + String(repeating: "W", count: 32),
        subtitle: state.subtitle, measurements: nil, symbol: state.symbol, tint: state.tint,
        accessibilityLabel: "long test network", accessibilityValue: state.subtitle,
        showsSettings: true, intent: .wifiDetails)
    let longRow = NetworkStatusView(state: longNameState, onOpenWiFiDetails: { _ in }, onOpenWiredDetails: {},
        onRequestNameAccess: {}, onOpenWiFiSettings: {}, onOpenNetworkSettings: {}, onOpenLocationSettings: {})
        .environmentObject(localization).frame(width: 302, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    let longSize = NSHostingView(rootView: longRow).fittingSize
    guard longSize.height > size.height else { print("FAIL: long network name did not wrap"); exit(1) }
    print("32-character network-name wrapping: PASS (\(longSize))")
    hosting.setFrameSize(size)
    hosting.layoutSubtreeIfNeeded()
    if let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: "build/wifi-row-layout.png"))
        }
    }
    print("Real Wi-Fi summary single-line layout: PASS")
    withExtendedLifetime(app) {}
}
