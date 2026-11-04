import Foundation
final class EqualSpacingTests: XCTestCase {
    func testUnequalPaddingBecomesEqualVisibleGaps() {
        let samples: [(PanelID, Int, Range<Int>)] = [(.cpu, 40, 3..<33), (.memory, 40, 2..<32), (.sensors, 44, 4..<29), (.network, 56, 2..<40), (.trio, 26, 3..<24)]
        let crops = samples.map { id, width, ink in
            (id, VisibleContentBounds.columns(width: width, height: 22) { x, y in ink.contains(x) && y == 10 }!)
        }
        let layout = CombinedLayout(widths: crops.map { ($0.0, CGFloat($0.1.count)) }, spacing: 4)
        for index in 1..<layout.regions.count {
            XCTAssertEqual(layout.regions[index].frame.minX - layout.regions[index-1].frame.maxX, 4)
            XCTAssertEqual(layout.target(atX: layout.regions[index].frame.midX), layout.regions[index].id)
        }
        XCTAssertEqual(crops.map { $0.1.count }, [30,30,25,38,21])
        XCTAssertNil(VisibleContentBounds.columns(width: 10, height: 22) { _,_ in false })
    }
}
