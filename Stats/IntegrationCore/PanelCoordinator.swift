import AppKit

public enum PanelID: String, CaseIterable {
    case cpu, memory, sensors, network, trio
}

public struct PanelAnchor {
    public let screenRect: CGRect
    public let visibleFrame: CGRect
    public init(screenRect: CGRect, visibleFrame: CGRect) {
        self.screenRect = screenRect
        self.visibleFrame = visibleFrame
    }
}

@MainActor
public protocol DetailPanel: AnyObject {
    var isVisible: Bool { get }
    var onDismiss: (() -> Void)? { get set }
    func show(at anchor: PanelAnchor)
    func reposition(to anchor: PanelAnchor)
    func dismiss()
}

@MainActor
public final class PanelCoordinator {
    private var panels: [PanelID: any DetailPanel] = [:]
    private var generation: UInt64 = 0
    public private(set) var activeID: PanelID?
    public init() {}
    public func register(_ panel: any DetailPanel, for id: PanelID) { panels[id] = panel }
    public func toggle(_ id: PanelID, anchor: PanelAnchor) {
        guard let panel = panels[id] else { return }
        if activeID == id, panel.isVisible {
            dismissAll()
            return
        }
        dismissAll()
        generation &+= 1
        let token = generation
        activeID = id
        panel.onDismiss = { [weak self, weak panel] in
            guard let self, let panel, !panel.isVisible,
                  self.generation == token, self.activeID == id else { return }
            self.activeID = nil
        }
        panel.show(at: anchor)
    }
    public func dismissAll() {
        generation &+= 1
        let previous = activeID
        activeID = nil
        if let previous { panels[previous]?.dismiss() }
    }
    public func updateAnchor(_ anchor: PanelAnchor, for id: PanelID) {
        guard activeID == id, let panel = panels[id], panel.isVisible else { return }
        panel.reposition(to: anchor)
    }
}

public enum PanelPlacement {
    public static func frame(size: CGSize, anchor: PanelAnchor) -> CGRect {
        let screen = anchor.visibleFrame.insetBy(dx: 3, dy: 3)
        let width = min(max(1, size.width), max(1, screen.width))
        let height = min(max(1, size.height), max(1, screen.height))
        let x = min(max(anchor.screenRect.midX - width / 2, screen.minX), screen.maxX - width)
        let y = min(max(anchor.screenRect.minY - 3 - height, screen.minY), screen.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
