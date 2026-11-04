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

MainActor.assumeIsolated {
let value = NSView(frame: NSRect(x: 0, y: 0, width: 24, height: 22))
let slot = MenuSlotView(content: value, width: 32, leadingInset: 2)
let initial = slot.frame
for width in [18.0, 32, 70, 24] {
    value.setFrameSize(NSSize(width: width, height: 22))
    precondition(slot.frame == initial, "numeric width moved the fixed slot")
    precondition(value.frame.minX == -2, "numeric width moved the content anchor")
}
print("Real AppKit fixed slot and stable numeric origin: PASS")
}

final class BlackCanvas: NSView {
    override func draw(_ dirtyRect: NSRect) { NSColor.black.setFill(); bounds.fill() }
}
MainActor.assumeIsolated {
    let canvas = BlackCanvas(frame: NSRect(x: 0, y: 0, width: 166, height: 22))
    canvas.appearance = NSAppearance(named: .darkAqua)
    let cpu = Mini(title: "CPU", config: ["Preview": ["Title":"CPU", "Label":true, "Value":"0.56"]], preview: true)
    let ram = Mini(title: "RAM", config: ["Preview": ["Title":"RAM", "Label":true, "Value":"0.85"]], preview: true)
    let sensors = StackWidget(title: "Sensors", config: ["Preview": ["Values":"18W,43°"]], preview: true)
    Store.shared.set(key: "Network_speed_icon", value: "none")
    Store.shared.set(key: "Network_speed_valueAlignment", value: "left")
    let net = SpeedWidget(title: "Network", config: nil)
    net.setValue(input: 343 * 1024, output: Int64(7.3 * 1024 * 1024))
    for (content, x, width, inset) in [(cpu as NSView,0.0,32.0,2.0),(ram as NSView,32,32,2),(sensors as NSView,64,30,4),(net as NSView,94,46,2)] {
        let source = NSView(frame: NSRect(x: 0, y: 0, width: 70, height: 22))
        source.addSubview(content)
        content.setFrameOrigin(NSPoint(x: 2, y: 2))
        let slot = MenuSlotView(content: source, width: width, leadingInset: inset)
        canvas.addSubview(slot)
        slot.setFrameOrigin(NSPoint(x: x, y: 0))
    }
    if let icon = NSImage(contentsOfFile: "build/compact-battery-full.png") {
        let image = NSImageView(frame: NSRect(x: 142, y: 0, width: 22, height: 22))
        image.image = icon
        canvas.addSubview(image)
    }
    if let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) {
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        if let png = bitmap.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "build/fixed-layout-reference.png"))
        }
    }
}
