import Foundation
final class FixedMenuLayoutTests: XCTestCase {
    func testChangingNumericWidthsKeepsEveryRegionInPlace() {
        let ids: [PanelID] = [.cpu,.memory,.sensors,.network,.trio]
        let small = FixedMenuLayout.layout(items: zip(ids,[20,20,18,25,21]).map { ($0.0,CGFloat($0.1)) }, spacing: 0)
        let large = FixedMenuLayout.layout(items: zip(ids,[32,32,40,70,26]).map { ($0.0,CGFloat($0.1)) }, spacing: 0)
        XCTAssertEqual(small.regions.map(\.frame), large.regions.map(\.frame))
        XCTAssertEqual(small.width, large.width)
        XCTAssertEqual(small.regions.map { $0.frame.minX }, [0,32,64,94,140])
        for index in 1..<small.regions.count {
            XCTAssertEqual(small.regions[index].frame.minX - small.regions[index-1].frame.maxX, 0)
            XCTAssertEqual(small.target(atX: small.regions[index].frame.midX), ids[index])
        }
    }
}
