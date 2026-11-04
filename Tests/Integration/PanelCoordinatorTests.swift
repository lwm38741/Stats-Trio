import AppKit

@MainActor
final class FakePanel: DetailPanel {
    var isVisible = false
    var onDismiss: (() -> Void)?
    var anchors: [PanelAnchor] = []
    var shows = 0
    func show(at anchor: PanelAnchor) { shows += 1; anchors.append(anchor); isVisible = true }
    func reposition(to anchor: PanelAnchor) { anchors.append(anchor) }
    func dismiss() { isVisible = false; onDismiss?() }
}

@MainActor
final class PanelCoordinatorTests: XCTestCase {
    let anchor = PanelAnchor(screenRect: CGRect(x: 300, y: 900, width: 32, height: 24),
                             visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 900))
    func testSwitchSameClickAndLateDismissal() {
        let coordinator = PanelCoordinator()
        let cpu = FakePanel(), trio = FakePanel(), settings = FakePanel()
        settings.show(at: anchor)
        coordinator.register(cpu, for: .cpu)
        coordinator.register(trio, for: .trio)
        coordinator.toggle(.cpu, anchor: anchor)
        XCTAssertTrue(cpu.isVisible)
        let late = cpu.onDismiss
        coordinator.toggle(.trio, anchor: anchor)
        XCTAssertFalse(cpu.isVisible)
        XCTAssertTrue(trio.isVisible)
        late?()
        XCTAssertEqual(coordinator.activeID, .trio)
        coordinator.toggle(.trio, anchor: anchor)
        XCTAssertFalse(trio.isVisible)
        XCTAssertNil(coordinator.activeID)
        coordinator.dismissAll()
        coordinator.dismissAll()
        XCTAssertTrue(settings.isVisible)
    }
    func testLateDismissalCannotCloseReopenedSamePanel() {
        let coordinator = PanelCoordinator(), cpu = FakePanel()
        coordinator.register(cpu, for: .cpu)
        coordinator.toggle(.cpu, anchor: anchor)
        let late = cpu.onDismiss
        coordinator.toggle(.cpu, anchor: anchor)
        coordinator.toggle(.cpu, anchor: anchor)
        late?()
        XCTAssertEqual(coordinator.activeID, .cpu)
        XCTAssertTrue(cpu.isVisible)
    }
    func testNegativeScreenAndTallPanelPlacement() {
        let negative = PanelAnchor(screenRect: CGRect(x: -1440, y: 900, width: 24, height: 24),
                                   visibleFrame: CGRect(x: -1440, y: 0, width: 1440, height: 900))
        let frame = PanelPlacement.frame(size: CGSize(width: 400, height: 300), anchor: negative)
        XCTAssertEqual(frame.minX, -1437)
        XCTAssertEqual(frame.minY, 597)
        XCTAssertTrue(negative.visibleFrame.contains(frame))
        let tall = PanelPlacement.frame(size: CGSize(width: 330, height: 1500), anchor: negative)
        XCTAssertEqual(tall.height, 894)
        XCTAssertTrue(negative.visibleFrame.contains(tall))
    }
    func testDismissCallbackWhileVisibleKeepsOwnership() {
        let coordinator = PanelCoordinator(), cpu = FakePanel(), trio = FakePanel()
        coordinator.register(cpu, for: .cpu)
        coordinator.register(trio, for: .trio)
        coordinator.toggle(.cpu, anchor: anchor)
        cpu.onDismiss?()
        XCTAssertEqual(coordinator.activeID, .cpu)
        coordinator.toggle(.trio, anchor: anchor)
        XCTAssertFalse(cpu.isVisible)
    }
    func testOpenPanelTracksLayoutWithoutReopening() {
        let coordinator = PanelCoordinator(), cpu = FakePanel()
        coordinator.register(cpu, for: .cpu)
        coordinator.toggle(.cpu, anchor: anchor)
        let moved = PanelAnchor(screenRect: CGRect(x: 350, y: 900, width: 32, height: 24), visibleFrame: anchor.visibleFrame)
        coordinator.updateAnchor(moved, for: .cpu)
        XCTAssertEqual(cpu.anchors.last?.screenRect.minX, 350)
        XCTAssertEqual(cpu.shows, 1)
        XCTAssertEqual(coordinator.activeID, .cpu)
    }
}
