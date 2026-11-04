import AppKit

@MainActor
final class CroppedMenuContentView: NSView {
    init(content: NSView, visibleBounds: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: visibleBounds.width, height: content.frame.height))
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(content)
        content.setFrameOrigin(NSPoint(x: -visibleBounds.minX, y: 0))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
enum MenuContentCropping {
    static func visibleBounds(of view: NSView) -> NSRect {
        guard view.bounds.width > 0, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return view.bounds }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let columns = VisibleContentBounds.columns(width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
            visible: { x, y in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.02 }) else { return view.bounds }
        let scale = view.bounds.width / CGFloat(bitmap.pixelsWide)
        return NSRect(x: CGFloat(columns.lowerBound) * scale, y: 0,
                      width: CGFloat(columns.count) * scale, height: view.bounds.height)
    }

}
