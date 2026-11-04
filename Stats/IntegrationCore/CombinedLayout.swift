import Foundation

public struct MenuRegion {
    public let id: PanelID
    public let frame: CGRect
}

public struct CombinedLayout {
    public let regions: [MenuRegion]
    public let width: CGFloat
    public init(widths: [(PanelID, CGFloat)], spacing: CGFloat, height: CGFloat = 22) {
        var regions: [MenuRegion] = []
        var x: CGFloat = 0
        let gap = spacing.isFinite ? max(0, spacing) : 2
        for (id, width) in widths where width.isFinite && width > 0 {
            if !regions.isEmpty { x += gap }
            regions.append(MenuRegion(id: id, frame: CGRect(x: x, y: 0, width: width, height: height)))
            x += width
        }
        self.regions = regions
        self.width = x
    }
    public func target(atX x: CGFloat) -> PanelID? {
        regions.first { x >= $0.frame.minX && x < $0.frame.maxX }?.id
    }
}
