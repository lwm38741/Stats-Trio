import AppKit
import Foundation

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)
let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let side = CGFloat(pixels)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(srgbRed: 0.12, green: 0.42, blue: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: side * 0.06, y: side * 0.06, width: side * 0.88, height: side * 0.88),
                     xRadius: side * 0.20, yRadius: side * 0.20).fill()
        let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(paletteColors: [.white]))!
        symbol.draw(in: CGRect(x: side * 0.20, y: side * 0.20, width: side * 0.60, height: side * 0.60))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let file = destination.appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: file)
    }
}
