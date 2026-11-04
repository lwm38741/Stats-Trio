import Foundation

enum CompactBatteryPresentation {
    static func options(for battery: BatteryStatus) -> BatteryIconOptions {
        BatteryIconOptions(showsPercentage: false,
                           showsChargingIndicator: battery.isCharging && !battery.isCharged,
                           showsChargingEffect: false,
                           showsChargingBoltHeartbeat: false)
    }
    static func scene(battery: BatteryStatus) -> IconSceneState {
        let snapshot = StatusSnapshot(battery: battery, wifi: .placeholder, volume: .placeholder)
        return IconPresentationMapper.scene(inputs: IconPresentationInputs(snapshot: snapshot, audioIcon: nil),
            configuration: IconPresentationConfiguration(battery: options(for: battery), connection: .standard,
                                                        volume: .standard, bluetooth: .standard))
    }
}
