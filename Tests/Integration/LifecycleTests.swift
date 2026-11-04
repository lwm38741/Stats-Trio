import Foundation

final class LifecycleTests: XCTestCase {
    func testTwentyTimerCyclesReleaseWithoutLateCallbacks() {
        let lock = NSLock()
        var callbacks = 0
        weak var released: Repeater?
        do {
            let timer = Repeater(seconds: 1) {
                lock.lock(); callbacks += 1; lock.unlock()
            }
            released = timer
            for _ in 0..<20 {
                timer.start()
                timer.start()
                timer.pause()
                timer.pause()
            }
        }
        XCTAssertNil(released)
        Thread.sleep(forTimeInterval: 1.2)
        lock.lock(); let observed = callbacks; lock.unlock()
        XCTAssertEqual(observed, 0)
    }
}
