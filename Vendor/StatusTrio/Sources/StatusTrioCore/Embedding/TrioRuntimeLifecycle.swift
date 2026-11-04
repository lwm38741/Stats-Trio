import Foundation

/// Main-thread ownership of the embedded runtime; stop is terminal, like its store.
final class TrioRuntimeLifecycle {
    private let begin: () -> Void
    private let end: () -> Void
    private let visibility: (Bool) -> Void
    private var started = false
    private var stopped = false
    private var visible = false

    init(start: @escaping () -> Void, stop: @escaping () -> Void, visibility: @escaping (Bool) -> Void) {
        begin = start
        end = stop
        self.visibility = visibility
    }
    func start() {
        guard !started, !stopped else { return }
        started = true
        begin()
    }
    func setPanelVisible(_ value: Bool) {
        guard started, !stopped, visible != value else { return }
        visible = value
        visibility(value)
    }
    func stop() {
        guard started, !stopped else { return }
        setPanelVisible(false)
        stopped = true
        end()
    }
}
