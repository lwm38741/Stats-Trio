import Foundation

final class NetworkInterfaceSelectionTests: XCTestCase {
    func testAutomaticAndMissingInterfacesFollowPrimary() {
        let present: Set<String> = ["en0", "en5"]
        for requested in [nil, "", "missing0"] as [String?] {
            XCTAssertEqual(NetworkInterfaceSelection.resolve(requested: requested, primary: "en5", isPresent: present.contains), "en5")
        }
        XCTAssertEqual(NetworkInterfaceSelection.resolve(requested: "en0", primary: "en5", isPresent: present.contains), "en0")
        XCTAssertEqual(NetworkInterfaceSelection.resolve(requested: "en0", primary: "en5", isPresent: { _ in false }), "en5")
    }
}
