import Foundation

final class TrioEmbeddedRuntimeTests: XCTestCase {
    func testStartStopIsIdempotentAndHiddenPanelStopsDetailWork() {
        var events: [String] = []
        let lifetime = TrioRuntimeLifecycle(start: { events.append("start") },
                                             stop: { events.append("stop") },
                                             visibility: { events.append($0 ? "visible" : "hidden") })
        lifetime.start()
        lifetime.start()
        lifetime.setPanelVisible(true)
        lifetime.setPanelVisible(true)
        lifetime.setPanelVisible(false)
        lifetime.stop()
        lifetime.stop()
        XCTAssertEqual(events, ["start", "visible", "hidden", "stop"])
    }
}
