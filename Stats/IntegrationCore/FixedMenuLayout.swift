import Foundation

/// Numeric updates may redraw a widget, but never change its allocated menu slot.
enum FixedMenuLayout {
    static func width(for id: PanelID) -> CGFloat {
        switch id {
        case .cpu, .memory: return 32
        case .sensors: return 30
        case .network: return 46
        case .trio: return 26
        }
    }
    static func layout(items: [(PanelID, CGFloat)], spacing: CGFloat) -> CombinedLayout {
        CombinedLayout(widths: items.map { ($0.0, width(for: $0.0)) }, spacing: spacing)
    }
}
