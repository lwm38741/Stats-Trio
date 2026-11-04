import AppKit
import Kit

@MainActor
private final class CombinedGroupView: NSView {
    var layout = CombinedLayout(widths: [], spacing: 2)
    var clicked: ((PanelID) -> Void)?
    var contextMenu: NSMenu?
    override func mouseDown(with event: NSEvent) {
        if let id = layout.target(atX: convert(event.locationInWindow, from: nil).x) { clicked?(id) }
    }
    override func rightMouseDown(with event: NSEvent) {
        if let contextMenu { NSMenu.popUpContextMenu(contextMenu, with: event, for: self) }
    }
}

@MainActor
final class CombinedView: NSObject {
    private let item: NSStatusItem
    private let group = CombinedGroupView(frame: .zero)
    private let trioButton = NSButton(frame: NSRect(x: 0, y: 0, width: 26, height: 22))
    private let coordinator: PanelCoordinator
    private let trio: TrioBridge
    private let modules: [Module]
    private var regionViews: [PanelID: NSView] = [:]
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var isRecalculating = false
    private var layoutUpdatePending = false
    private var appearanceObservation: NSKeyValueObservation?
    var openSettings: () -> Void = {}

    init(modules: [Module], coordinator: PanelCoordinator, trio: TrioBridge) {
        self.modules = modules
        self.coordinator = coordinator
        self.trio = trio
        item = NSStatusBar.system.statusItem(withLength: 26)
        super.init()
        item.autosaveName = "StatsTrioCombined"
        item.button?.addSubview(group)
        item.button?.image = NSImage()
        item.button?.toolTip = "Stats Trio"
        group.clicked = { [weak self] in self?.toggle($0) }
        trioButton.isBordered = false
        trioButton.imagePosition = .imageOnly
        trioButton.imageScaling = .scaleProportionallyDown
        trioButton.target = self
        trioButton.action = #selector(clickTrio)
        trioButton.setAccessibilityLabel("Trio：电池、网络、蓝牙与声音")
        trioButton.toolTip = "Trio"
        trio.anchorView = trioButton
        trio.runtime.onIconChanged = { [weak self] in self?.refreshTrioIcon() }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(settings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "关于 Stats Trio", action: #selector(about), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Stats Trio", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        group.contextMenu = menu
        for module in modules {
            module.menuBar.callback = { [weak self] in
                DispatchQueue.main.async { self?.recalculate() }
            }
            module.onPopupRequested = { [weak self] in
                if let id = Self.id(for: module.name) { self?.toggle(id) }
            }
            module.popupShouldDismissOnResign = { [weak self] in
                !(self?.containsMenuPoint(NSEvent.mouseLocation) ?? false)
            }
        }
        for name in [Notification.Name.toggleModule, .moduleRearrange, .toggleWidget] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { self?.recalculate() }
            })
        }
        installDismissalMonitors()
        recalculate()
        refreshTrioIcon()
    }

    static func id(for name: String) -> PanelID? {
        switch name {
        case "CPU": return .cpu
        case "RAM": return .memory
        case "Sensors": return .sensors
        case "Network": return .network
        default: return nil
        }
    }

    func recalculate() {
        guard !isRecalculating else { return }
        isRecalculating = true
        defer { isRecalculating = false }
        group.subviews.forEach { $0.removeFromSuperview() }
        regionViews.removeAll()
        var widths: [(PanelID, CGFloat)] = []
        let sorted = modules.enumerated().filter { $0.element.enabled }.sorted {
            if $0.element.combinedPosition == $1.element.combinedPosition { return $0.offset < $1.offset }
            return $0.element.combinedPosition < $1.element.combinedPosition
        }.map(\.element)
        for module in sorted {
            guard let id = Self.id(for: module.name) else { continue }
            let source = module.menuBar.view
            let view = CroppedMenuContentView(content: source, visibleBounds: MenuContentCropping.visibleBounds(of: source))
            widths.append((id, view.frame.width))
            regionViews[id] = view
            for widget in module.menuBar.widgets where widget.isActive {
                (widget.item as? WidgetWrapper)?.onContentRendered = { [weak self] in self?.scheduleLayoutUpdate() }
                widget.item.onClick = { [weak self] in self?.toggle(id) }
                widget.item.setAccessibilityLabel(module.name)
            }
        }
        let trioView = CroppedMenuContentView(content: trioButton, visibleBounds: MenuContentCropping.visibleBounds(of: trioButton))
        widths.append((.trio, trioView.frame.width))
        regionViews[.trio] = trioView
        let spacing = CGFloat(Int(Store.shared.string(key: "CombinedModules_spacing", defaultValue: "2")) ?? 2)
        let layout = CombinedLayout(widths: widths, spacing: spacing)
        group.layout = layout
        for region in layout.regions {
            guard let view = regionViews[region.id] else { continue }
            group.addSubview(view)
            view.setFrameOrigin(region.frame.origin)
        }
        group.setFrameSize(NSSize(width: layout.width, height: 22))
        item.length = layout.width
        group.setFrameOrigin(NSPoint(x: 0, y: max(0, ((item.button?.bounds.height ?? 22) - 22) / 2)))
        if let active = coordinator.activeID, regionViews[active]?.superview == nil { coordinator.dismissAll() }
        if let active = coordinator.activeID, let currentAnchor = anchor(for: active) {
            coordinator.updateAnchor(currentAnchor, for: active)
        }
    }

    private func scheduleLayoutUpdate() {
        guard !isRecalculating, !layoutUpdatePending else { return }
        layoutUpdatePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutUpdatePending = false
            self.recalculate()
        }
    }
    func anchor(for id: PanelID) -> PanelAnchor? {
        guard let view = regionViews[id], let window = view.window, let screen = window.screen else { return nil }
        let rect = window.convertToScreen(view.convert(view.bounds, to: nil))
        return PanelAnchor(screenRect: rect, visibleFrame: screen.visibleFrame)
    }
    func toggle(_ id: PanelID) {
        guard let anchor = anchor(for: id) else { return }
        coordinator.toggle(id, anchor: anchor)
    }
    private func containsMenuPoint(_ point: NSPoint) -> Bool {
        guard let window = group.window else { return false }
        return window.convertToScreen(group.convert(group.bounds, to: nil)).contains(point)
    }
    private func refreshTrioIcon() {
        trioButton.image = trio.runtime.renderIcon(size: 22,
            scale: group.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2,
            appearance: group.effectiveAppearance)
    }
    private func installDismissalMonitors() {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown {
                if event.keyCode == 53, self.coordinator.activeID != nil { self.coordinator.dismissAll(); return nil }
                return event
            }
            if self.containsMenuPoint(NSEvent.mouseLocation) { return event }
            if let number = event.window?.windowNumber,
               number == self.trio.runtime.panelWindowNumber || self.modules.contains(where: { $0.popupWindowNumber == number }) { return event }
            self.coordinator.dismissAll()
            return event
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            guard let self, !self.containsMenuPoint(NSEvent.mouseLocation) else { return }
            self.coordinator.dismissAll()
        }) { monitors.append(monitor) }
        appearanceObservation = group.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshTrioIcon() }
        }
    }
    func stop() {
        coordinator.dismissAll()
        monitors.forEach(NSEvent.removeMonitor)
        observers.forEach(NotificationCenter.default.removeObserver)
        appearanceObservation = nil
        monitors.removeAll()
        observers.removeAll()
        NSStatusBar.system.removeStatusItem(item)
    }
    @objc private func clickTrio() { toggle(.trio) }
    @objc private func settings() { coordinator.dismissAll(); openSettings() }
    @objc private func about() { coordinator.dismissAll(); NSApp.orderFrontStandardAboutPanel(nil) }
    @objc private func quit() { NSApp.terminate(nil) }
}
