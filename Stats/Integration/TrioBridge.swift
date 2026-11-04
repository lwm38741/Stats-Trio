import AppKit
import TrioEmbedded

@MainActor
final class TrioBridge: DetailPanel {
    let runtime: TrioEmbeddedRuntime
    weak var anchorView: NSView?
    var onDismiss: (() -> Void)?
    var openSettings: () -> Void = {}
    private var installed = false
    var isVisible: Bool { runtime.isPanelVisible }
    init(defaults: UserDefaults) {
        runtime = TrioEmbeddedRuntime(defaults: defaults)
        runtime.onPanelDismiss = { [weak self] in self?.onDismiss?() }
    }
    func show(at anchor: PanelAnchor) {
        guard let view = anchorView, view.window != nil else { return }
        if !installed {
            _ = runtime.makePanelController(
                openSettings: { [weak self] in self?.dismiss(); self?.openSettings() },
                dismiss: { [weak self] in self?.dismiss() })
            installed = true
        }
        NSApp.activate(ignoringOtherApps: true)
        runtime.showPanel(relativeTo: view.bounds, of: view)
    }
    func dismiss() { runtime.dismissPanel() }
    func reposition(to anchor: PanelAnchor) {
        if let view = anchorView { runtime.updatePanelAnchor(of: view) }
    }
}
