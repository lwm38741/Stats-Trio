import Foundation

/// Brightness is excluded from this product, so the shared store gets no display reader.
@MainActor
final class DisabledBrightnessMonitor: BrightnessMonitoring {
    var updates: AsyncStream<BrightnessStatus> { AsyncStream { $0.finish() } }
    func start() {}
    func stop() {}
    func refresh() {}
    func recover() {}
}
