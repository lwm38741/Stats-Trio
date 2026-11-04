import AppKit
import Kit

@MainActor
final class StatsPanelAdapter: DetailPanel {
    private let module: Module
    private var anchor: PanelAnchor?
    var onDismiss: (() -> Void)?
    var isVisible: Bool { module.isPopupVisible }
    init(_ module: Module) {
        self.module = module
        module.onPopupSizeChanged = { [weak self] in
            guard let self, let anchor = self.anchor else { return }
            self.module.repositionPopup(in: PanelPlacement.frame(size: self.module.popupSize, anchor: anchor))
        }
        module.onPopupDismiss = { [weak self] in self?.onDismiss?() }
    }
    func show(at anchor: PanelAnchor) {
        self.anchor = anchor
        module.constrainPopup(to: anchor.visibleFrame.insetBy(dx: 3, dy: 3).size)
        module.showPopup(in: PanelPlacement.frame(size: module.popupSize, anchor: anchor))
    }
    func dismiss() { module.dismissPopup() }
    func reposition(to anchor: PanelAnchor) {
        self.anchor = anchor
        module.constrainPopup(to: anchor.visibleFrame.insetBy(dx: 3, dy: 3).size)
        module.repositionPopup(in: PanelPlacement.frame(size: module.popupSize, anchor: anchor))
    }
}
