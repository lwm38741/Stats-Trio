import Foundation

@MainActor
enum EmbeddedNetworkSummary {
    static func make(base: PanelSummaryState, wifi: WiFiStatus, connection: NetworkConnection,
                     hardware: TrioSummaryHardware?, localization: Localization) -> PanelSummaryState {
        guard connection == .wifi, wifi.state == .connected || wifi.state == .hotspot else {
            return connection == .ethernet ? base.appendingSummaryMetadata(hardware?.linkText) : base
        }
        let name = wifi.nameAccess == .authorized
            ? WiFiSummaryPresentation.summarySSID(wifi, connection: connection)?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        let title = localization.string(.wifiTitle) + ((name?.isEmpty == false) ? " · " + name! : "")
        let details = [WiFiSummaryPresentation.measurements(wifi, connection: connection, localization: localization),
                       hardware?.linkText].compactMap { $0 }.filter { !$0.isEmpty }
        let subtitle = details.joined(separator: " · ")
        return PanelSummaryState(title: title, subtitle: subtitle, measurements: subtitle.isEmpty ? nil : subtitle,
            symbol: base.symbol, tint: base.tint, accessibilityLabel: title, accessibilityValue: subtitle,
            showsSettings: base.showsSettings, intent: base.intent, powerInfoBar: base.powerInfoBar)
    }
}
