import Foundation
final class NetworkRateTests: XCTestCase {
    func testElapsedTimeAndBaselineResets() {
        var sampler = NetworkRateSampler()
        XCTAssertEqual(sampler.sample(upload: 100, download: 200, time: 10, scope: "en0").uploadRate, 0)
        let five = sampler.sample(upload: 150, download: 300, time: 15, scope: "en0")
        XCTAssertEqual(five.uploadRate, 10)
        XCTAssertEqual(five.downloadBytes, 100)
        XCTAssertEqual(sampler.sample(upload: 175, download: 350, time: 17.5, scope: "en0").downloadRate, 20)
        XCTAssertEqual(sampler.sample(upload: 900, download: 900, time: 18, scope: "en5").uploadRate, 0)
        XCTAssertEqual(sampler.sample(upload: 1, download: 1, time: 19, scope: "en5").downloadBytes, 0)
        sampler.reset()
        XCTAssertEqual(sampler.sample(upload: 500, download: 500, time: 40, scope: "en5").uploadRate, 0)
        XCTAssertEqual(sampler.sample(upload: 520, download: 540, time: 41, scope: "en5").downloadRate, 40)
    }
}
