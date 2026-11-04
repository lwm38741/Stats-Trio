import AppKit

@MainActor
final class MenuSlotView: NSView {
    init(content: NSView, width: CGFloat, leadingInset: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: content.frame.height))
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(content)
        // Remove only structural padding. The offset never depends on numeric ink.
        content.setFrameOrigin(NSPoint(x: -leadingInset, y: 0))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
