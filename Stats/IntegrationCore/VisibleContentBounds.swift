import Foundation

/// Finds the content columns without imposing identical widths on different widgets.
enum VisibleContentBounds {
    static func columns(width: Int, height: Int, visible: (Int, Int) -> Bool) -> Range<Int>? {
        guard width > 0, height > 0 else { return nil }
        func hasInk(_ x: Int) -> Bool { (0..<height).contains { visible(x, $0) } }
        guard let first = (0..<width).first(where: hasInk),
              let last = (0..<width).reversed().first(where: hasInk) else { return nil }
        return first..<(last + 1)
    }
}
