import Foundation

final class CombinedViewTests: XCTestCase {
    func testLayoutRoutesAndWidthChange() {
        let original = CombinedLayout(widths: [(.cpu, 30), (.memory, 40), (.sensors, 50), (.network, 60), (.trio, 24)], spacing: 2)
        XCTAssertEqual(original.regions.map(\.id), [.cpu, .memory, .sensors, .network, .trio])
        for (x, id) in [(15.0, PanelID.cpu), (50, .memory), (100, .sensors), (150, .network), (188.1, .trio), (200, .trio), (211.9, .trio)] {
            XCTAssertEqual(original.target(atX: x), id)
        }
        XCTAssertNil(original.target(atX: 31))
        XCTAssertNil(original.target(atX: 212))
        let changed = CombinedLayout(widths: [(.cpu, 50), (.memory, 40), (.sensors, 50), (.network, 60), (.trio, 24)], spacing: 2)
        XCTAssertEqual(changed.regions.first(where: { $0.id == .network })?.frame.minX, 146)
        XCTAssertEqual(changed.regions.first(where: { $0.id == .trio })?.frame.minX, 208)
    }
    func testZeroWidthModulesDoNotLeaveDeadSpacing() {
        let layout = CombinedLayout(widths: [(.cpu, 0), (.trio, 24)], spacing: 2)
        XCTAssertEqual(layout.width, 24)
        XCTAssertEqual(layout.target(atX: 12), .trio)
    }
}
