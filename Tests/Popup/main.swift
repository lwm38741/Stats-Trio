import AppKit
import Kit
let app = NSApplication.shared
final class Content: NSView, Popup_p {
    var keyboardShortcut: [UInt16] = []
    var sizeCallback: ((NSSize) -> Void)?
    func settings() -> NSView? { nil }
    func appear() {}
    func disappear() {}
    func setKeyboardShortcut(_ binding: [UInt16]) {}
}
let content = Content(frame: NSRect(x: 0, y: 0, width: 300, height: 900))
let popup = PopupWindow(title: "CPU", module: .CPU, view: content, visibilityCallback: { _ in })
popup.constrainContent(to: NSSize(width: 350, height: 240))
func verify() {
    precondition(popup.contentView!.frame.height <= 240, "content exceeded budget")
    let scroll = popup.contentView!.subviews.compactMap { $0 as? NSScrollView }.first!
    precondition(scroll.frame.maxY <= 240 && scroll.frame.height > 0, "viewport escaped budget")
    precondition(scroll.documentView!.frame.height > scroll.frame.height, "full content must scroll")
    for view in popup.contentView!.subviews { precondition(view.frame.maxY <= 240, "header/background clipped") }
}
verify()
var changes = 0
popup.onContentSizeChanged = { changes += 1 }
content.setFrameSize(NSSize(width: 300, height: 1500))
content.sizeCallback?(content.frame.size)
verify()
precondition(changes == 1, "growth did not notify anchored host")
print("Real PopupWindow short-screen and content-growth: PASS")

final class PaintedContent: NSView {
    let ink: NSRect
    init(width: CGFloat, ink: NSRect) {
        self.ink = ink
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) { NSColor.white.setFill(); ink.fill() }
}
MainActor.assumeIsolated {
let painted = PaintedContent(width: 50, ink: NSRect(x: 7, y: 3, width: 20, height: 12))
let optical = MenuContentCropping.visibleBounds(of: painted)
precondition(abs(optical.minX - 7) < 0.51 && abs(optical.width - 20) < 0.51, "real raster capture retained transparent padding")
let cropped = CroppedMenuContentView(content: painted, visibleBounds: optical)
precondition(abs(cropped.frame.width - 20) < 0.51 && painted.frame.minX == -optical.minX)
print("Real AppKit visible-content crop: PASS")

}
