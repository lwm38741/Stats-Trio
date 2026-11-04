import Foundation
import SystemConfiguration
import CoreWLAN
import IOKit.ps

struct TrioSummaryHardware: Sendable {
    let adapterWatts: Int?
    let linkMbps: Double?
    var adapterText: String {
        guard let watts = adapterWatts, watts > 0 else { return "电源适配器功率不可用" }
        return "电源适配器 · \(watts) W"
    }
    var linkText: String {
        guard let rate = linkMbps, rate.isFinite, rate > 0 else { return "握手速率不可用" }
        let value = rate >= 1000 ? rate / 1000 : rate
        let unit = rate >= 1000 ? "Gbps" : "Mbps"
        return "握手速率 · \(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }
    static func mediaMbps(_ subtype: String) -> Double? {
        let text = subtype.lowercased()
        guard text.contains("base"), let end = text.firstIndex(where: { !$0.isNumber && $0 != "." }),
              let value = Double(text[..<end]), value > 0 else { return nil }
        return text[end] == "g" ? value * 1000 : value
    }
    static func read(ethernet: Bool) -> Self {
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        let watts = (adapter?[kIOPSPowerAdapterWattsKey] as? NSNumber)?.intValue
        var rate: Double?
        if ethernet {
            let primary = (SCDynamicStoreCopyValue(nil, "State:/Network/Global/IPv4" as CFString) as? [String: Any])?["PrimaryInterface"] as? String
            let all = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
            let wired = all.filter { SCNetworkInterfaceGetInterfaceType($0) == kSCNetworkInterfaceTypeEthernet }
            let ordered = wired.sorted { (SCNetworkInterfaceGetBSDName($0) as String?) == primary && (SCNetworkInterfaceGetBSDName($1) as String?) != primary }
            for interface in ordered {
                var active: Unmanaged<CFDictionary>?
                if SCNetworkInterfaceCopyMediaOptions(interface, nil, &active, nil, false),
                   let media = active?.takeRetainedValue() as? [String: Any],
                   let subtype = media[kSCPropNetEthernetMediaSubType as String] as? String,
                   let measured = mediaMbps(subtype) {
                    rate = measured
                    break
                }
            }
        } else if let wifi = CWWiFiClient.shared().interface(), wifi.powerOn(), wifi.serviceActive() {
            let measured = wifi.transmitRate()
            if measured > 0 { rate = measured }
        }
        return Self(adapterWatts: watts.flatMap { $0 > 0 ? $0 : nil }, linkMbps: rate)
    }
}

extension PanelSummaryState {
    func appendingSummaryMetadata(_ text: String?) -> Self {
        guard let text else { return self }
        let subtitle = self.subtitle.isEmpty ? text : self.subtitle + " · " + text
        return Self(title: title, subtitle: subtitle, measurements: measurements, symbol: symbol, tint: tint,
                    accessibilityLabel: accessibilityLabel, accessibilityValue: title + ", " + subtitle,
                    showsSettings: showsSettings, intent: intent, powerInfoBar: powerInfoBar)
    }
}
