import CoreAudio
import Foundation

struct VolumeActionError: Equatable {
    let message: String
    let id = UUID()
}

@MainActor
protocol VolumeControlling: AnyObject {
    @discardableResult func setVolume(_ scalar: Double) -> Bool
    @discardableResult func toggleMute() -> Bool
    @discardableResult func selectOutputDevice(_ deviceID: AudioDeviceID) -> Bool
    func flushPendingVolume()
}

extension VolumeControlling {
    func flushPendingVolume() {}
}
