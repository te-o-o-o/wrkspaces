import AppKit

/// One app shown in a grid tile: its icon, and its pid to move it when dragged.
struct AppIcon {
    let pid: pid_t
    let icon: NSImage
}

/// Grid of the nine workspaces with their apps. Shown while ⌃ stays held after a workspace
/// shortcut (like Cmd-Tab), or from the menu bar icon. No fade: it appears and goes at once.
// Private, like _AXUIElementGetWindow: macOS only lets the active app set the cursor, and the
// grid must not take the focus. If Apple drops it, only the drag cursors are lost.
@_silgen_name("_CGSDefaultConnection") private func _CGSDefaultConnection() -> Int32
@_silgen_name("CGSSetConnectionProperty") private func CGSSetConnectionProperty(_: Int32, _: Int32, _: CFString, _: CFTypeRef) -> Int32

final class Switcher {
    private let panel: NSPanel
    let grid = GridView(frame: NSRect(x: 0, y: 0, width: GridView.width, height: 300))  // height set on show
    private var poll: Timer?
    private var outsideClick: Any?
    var onReleaseOnApp: ((pid_t) -> Void)?  // ⌃ released with an app selected

    var isVisible: Bool { panel.isVisible }

    init() {
        grid.autoresizingMask = [.width, .height]
        panel = NSPanel(contentRect: grid.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none
        panel.acceptsMouseMovedEvents = true
        let cid = _CGSDefaultConnection()
        _ = CGSSetConnectionProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The HUD material is dark whatever the system theme: keep the text light on it.
        panel.appearance = NSAppearance(named: .darkAqua)
        let blur = NSVisualEffectView(frame: grid.frame)
        blur.material = .hudWindow
        blur.state = .active
        // A stretchable mask, so the corners stay round when the icon row grows the panel.
        let mask = NSImage(size: NSSize(width: 37, height: 37), flipped: false) { r in
            NSBezierPath(roundedRect: r, xRadius: 18, yRadius: 18).fill()
            return true
        }
        mask.capInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        mask.resizingMode = .stretch
        blur.maskImage = mask
        blur.addSubview(grid)
        panel.contentView = blur
    }

    /// Centered, gone when ⌃ is released; while ⌃ stays held, click or drag like in `showBelow`.
    func showWhileControlHeld(_ apps: [[AppIcon]], current: Int) {
        update(apps, current: current)
        guard !panel.isVisible else { return }
        resize(showsIcons: false)
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - panel.frame.width / 2, y: screen.frame.midY - panel.frame.height / 2))
        }
        panel.orderFrontRegardless()
        // ponytail: polls ⌃ at 20 Hz while visible instead of a global flagsChanged monitor.
        poll = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, !NSEvent.modifierFlags.contains(.control) else { return }
            let picked = grid.selected
            hide()
            if let picked { onReleaseOnApp?(picked) }
        }
    }

    /// Under the menu bar icon, with the icon picker below the grid: click a workspace
    /// to go there, an icon to use it, anywhere else to close.
    func showBelow(_ anchor: NSRect, _ apps: [[AppIcon]], current: Int) {
        update(apps, current: current)
        resize(showsIcons: true)
        var x = anchor.midX - panel.frame.width / 2
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor.origin) }) {
            x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - panel.frame.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: anchor.minY - panel.frame.height - 6))
        panel.orderFrontRegardless()
        // A global monitor only sees clicks in other apps: exactly "outside the grid". The menu
        // bar icon counts as another app here, so skip it: its own click toggles the grid, and
        // closing on mouse down would reopen it on mouse up.
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if !anchor.contains(NSEvent.mouseLocation) { self?.hide() }
        }
    }

    func hide() {
        poll?.invalidate()
        poll = nil
        if let m = outsideClick { NSEvent.removeMonitor(m) }
        outsideClick = nil
        grid.leave()
        grid.selected = nil
        panel.orderOut(nil)
    }

    private func resize(showsIcons: Bool) {
        grid.showsIcons = showsIcons
        panel.setContentSize(grid.size(showsIcons: showsIcons, showsShortcuts: GridView.showsShortcuts))
    }

    /// Draws now rather than on the next pass, so the new tile lights up before the windows move.
    func highlight(_ n: Int) {
        grid.current = n
        grid.display()
    }

    func update(_ apps: [[AppIcon]], current: Int) {
        grid.apps = apps
        grid.current = current
        grid.needsDisplay = true
    }
}

final class GridView: NSView {
    static let tile = NSSize(width: 140, height: 104)
    static let appsPerTile = 8  // two rows of 4 × 28 px; more shows as "+N"
    static let gap: CGFloat = 10
    static let pad: CGFloat = 16
    static let iconBox: CGFloat = 32
    static let lineHeight: CGFloat = 18
    static let width = pad * 2 + tile.width * 3 + gap * 2
    // Vertical layout, top-down: tiles (3 per row, as many rows as workspaces need), then
    // (from the menu bar icon only) icons, the shortcuts toggle and, when unfolded, the shortcut lines.
    var rows: CGFloat { CGFloat(max(1, (apps.count + 2) / 3)) }
    var tilesBottom: CGFloat { Self.pad + Self.tile.height * rows + Self.gap * (rows - 1) }
    var iconsTop: CGFloat { tilesBottom + Self.gap * 1.5 }
    var toggleTop: CGFloat { iconsTop + Self.iconBox + 8 }
    var linesTop: CGFloat { toggleTop + Self.lineHeight + 4 }
    var shortcuts: [(String, String)] { [
        ("⌃1 … ⌃\(apps.count)", "Go to workspace"),
        ("⌃N again", "Pick one of its apps"),
        ("⌃⇧1 … ⌃⇧\(apps.count)", "Take the window there"),
        ("Keypad 1 … \(apps.count)", "Same, with ⌃ or ⌃⇧"),
        ("Hold ⌃", "Show this grid"),
        ("Drag an app", "Send it to that workspace"),
        ("…onto an app", "Reorder them"),
        ("Right-click icon", "Workspaces, open at login, quit"),
    ] }

    func size(showsIcons: Bool, showsShortcuts: Bool) -> NSSize {
        let bottom = !showsIcons ? tilesBottom
            : showsShortcuts ? linesTop + CGFloat(shortcuts.count) * Self.lineHeight
            : toggleTop + Self.lineHeight
        return NSSize(width: Self.width, height: bottom + Self.pad)
    }

    static var showsShortcuts: Bool {
        get { UserDefaults.standard.bool(forKey: "showShortcuts") }
        set { UserDefaults.standard.set(newValue, forKey: "showShortcuts") }
    }

    var apps: [[AppIcon]] = []  // per workspace, in its fixed order
    var current = 1
    var selected: pid_t?  // app of the current tile picked by ⌃N again, focused when ⌃ is released
    var showsIcons = false
    var onPick: ((Int) -> Void)?
    var onPickIcon: ((IconStyle) -> Void)?
    var onMoveApp: ((pid_t, Int, Int) -> Void)?  // pid, from, to
    var onReorderApp: ((pid_t, pid_t?, Int) -> Void)?  // pid, the app it now goes before (nil: last), workspace
    private var press: (tile: Int, app: Int?)?  // where the mouse went down in the tiles
    private var dragAt: NSPoint?  // cursor while an app icon is dragged
    private var hover: NSPoint?  // cursor over the grid, to highlight what a click would hit

    // activeAlways: the panel never becomes key, so the default tracking would never fire.
    // inVisibleRect follows the view's size, so one area added once is enough.
    override func viewDidMoveToWindow() {
        guard window != nil, trackingAreas.isEmpty else { return }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        hover = convert(event.locationInWindow, from: nil)
        updateCursor()
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) { leave() }

    /// Also when the panel closes under the cursor, or the hand would stay.
    func leave() {
        guard hover != nil || dragAt != nil else { return }
        hover = nil
        NSCursor.arrow.set()
        needsDisplay = true
    }

    /// An open hand over an app icon says it can be dragged, a closed one while it is.
    private func updateCursor() {
        if dragAt != nil {
            NSCursor.closedHand.set()
        } else if let p = hover, let i = tile(at: p), apps[i].prefix(Self.appsPerTile).indices.contains(where: { appRect(i, $0).contains(p) }) {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func isHovered(_ r: NSRect) -> Bool { dragAt == nil && hover.map(r.contains) == true }

    override var isFlipped: Bool { true }  // workspace 1 top-left, like a numpad read top-down

    // The panel never becomes key, so the first click must count.
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }

    // A click on a tile picks it on mouse up; dragging one of its app icons onto another
    // tile moves that app there instead.
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let i = tile(at: p) {
            press = (i, apps[i].prefix(Self.appsPerTile).indices.first { appRect(i, $0).contains(p) })
            return
        }
        guard showsIcons else { return }
        if let style = IconStyle.allCases.first(where: { iconRect($0).contains(p) }) { onPickIcon?(style) }
        if toggleRect.contains(p) {
            Self.showsShortcuts.toggle()
            // Grow or shrink downwards: the panel hangs from the menu bar.
            if let w = window {
                let size = size(showsIcons: true, showsShortcuts: Self.showsShortcuts)
                w.setFrame(NSRect(x: w.frame.minX, y: w.frame.maxY - size.height, width: size.width, height: size.height), display: true)
            }
            needsDisplay = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard press?.app != nil else { return }
        dragAt = convert(event.locationInWindow, from: nil)
        updateCursor()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            press = nil
            dragAt = nil
            hover = convert(event.locationInWindow, from: nil)
            updateCursor()
            needsDisplay = true
        }
        guard let press else { return }
        let p = convert(event.locationInWindow, from: nil)
        let target = tile(at: p)
        if let k = press.app, dragAt != nil, let target, target != press.tile {
            onMoveApp?(apps[press.tile][k].pid, press.tile + 1, target + 1)
        } else if let k = press.app, dragAt != nil, target == press.tile, let t = reorderSlot(at: p) {
            // It takes the place of the icon it is dropped on: before it going left, after it going right.
            let row = apps[press.tile]
            onReorderApp?(row[k].pid, t < k ? row[t].pid : row.indices.contains(t + 1) ? row[t + 1].pid : nil, press.tile + 1)
        } else if target == press.tile {
            // Released on its own tile, even after a jitter, is a click.
            onPick?(press.tile + 1)
        }
    }

    func tile(at p: NSPoint) -> Int? { apps.indices.first { tileRect($0).contains(p) } }

    /// While an app icon is dragged within its own tile: the other icon it is over, if any.
    private func reorderSlot(at p: NSPoint) -> Int? {
        guard let press, let k = press.app, tile(at: p) == press.tile else { return nil }
        return apps[press.tile].prefix(Self.appsPerTile).indices.first { $0 != k && appRect(press.tile, $0).insetBy(dx: -2, dy: -2).contains(p) }
    }

    /// The k-th app icon of tile i: up to 4 apps, one centered row; beyond, a grid of two rows
    /// of 4 filled from the top-left, so the 5th app sits under the 1st.
    func appRect(_ i: Int, _ k: Int) -> NSRect {
        let r = tileRect(i), side: CGFloat = 28, step = side + 4
        let columns = min(4, apps[i].count)
        let x = r.midX - (CGFloat(columns) * step - 4) / 2 + CGFloat(k % 4) * step
        return NSRect(x: x, y: r.maxY - 10 - 2 * side - 4 + CGFloat(k / 4) * step, width: side, height: side)
    }

    var toggleRect: NSRect { NSRect(x: Self.pad, y: toggleTop, width: bounds.width - Self.pad * 2, height: Self.lineHeight) }

    func iconRect(_ style: IconStyle) -> NSRect {
        let (box, gap) = (Self.iconBox, Self.gap)
        let k = CGFloat(IconStyle.allCases.firstIndex(of: style)!)
        let row = CGFloat(IconStyle.allCases.count) * (box + gap) - gap
        return NSRect(x: bounds.midX - row / 2 + k * (box + gap), y: iconsTop, width: box, height: box)
    }

    func tileRect(_ i: Int) -> NSRect {
        let (tile, gap, pad) = (Self.tile, Self.gap, Self.pad)
        return NSRect(x: pad + CGFloat(i % 3) * (tile.width + gap), y: pad + CGFloat(i / 3) * (tile.height + gap),
                      width: tile.width, height: tile.height)
    }

    override func draw(_: NSRect) {
        // Opaque: the blur turns light grey over a bright wallpaper or a white page and the
        // numbers fade. A solid dark grey reads the same whatever is behind.
        NSColor(white: 0.2, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 18, yRadius: 18).fill()
        for (i, icons) in apps.enumerated() {
            let r = tileRect(i)
            let box = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
            let isCurrent = i + 1 == current
            (isCurrent ? NSColor.controlAccentColor.withAlphaComponent(0.3) : NSColor.labelColor.withAlphaComponent(isHovered(r) ? 0.16 : 0.06)).setFill()
            box.fill()
            if isCurrent {
                NSColor.controlAccentColor.setStroke()
                box.lineWidth = 2
                box.stroke()
            }
            ("\(i + 1)" as NSString).draw(at: NSPoint(x: r.minX + 9, y: r.minY + 6), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
            if dragAt != nil, let p = dragAt, tile(at: p) == i, i != press?.tile {
                NSColor.labelColor.withAlphaComponent(0.6).setStroke()
                box.lineWidth = 2
                box.stroke()
            }
            for k in icons.prefix(Self.appsPerTile).indices {
                if isCurrent, icons[k].pid == selected {
                    NSColor.controlAccentColor.setFill()
                    NSBezierPath(roundedRect: appRect(i, k).insetBy(dx: -4, dy: -4), xRadius: 8, yRadius: 8).fill()
                } else if isHovered(appRect(i, k)) {
                    NSColor.labelColor.withAlphaComponent(0.2).setFill()
                    NSBezierPath(roundedRect: appRect(i, k).insetBy(dx: -3, dy: -3), xRadius: 7, yRadius: 7).fill()
                }
                if let p = dragAt, press?.tile == i, reorderSlot(at: p) == k {
                    NSColor.labelColor.withAlphaComponent(0.6).setStroke()
                    let ring = NSBezierPath(roundedRect: appRect(i, k).insetBy(dx: -3, dy: -3), xRadius: 7, yRadius: 7)
                    ring.lineWidth = 2
                    ring.stroke()
                }
                let dragged = dragAt != nil && press?.tile == i && press?.app == k
                icons[k].icon.draw(in: appRect(i, k), from: .zero, operation: .sourceOver, fraction: dragged ? 0.3 : 1,
                                   respectFlipped: true, hints: nil)
            }
            if icons.count > Self.appsPerTile {
                ("+\(icons.count - Self.appsPerTile)" as NSString).draw(at: NSPoint(x: r.maxX - 26, y: r.minY + 6), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor,
                ])
            }
        }
        if let p = dragAt, let press, let k = press.app {
            apps[press.tile][k].icon.draw(in: NSRect(x: p.x - 16, y: p.y - 16, width: 32, height: 32), from: .zero,
                                          operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        guard showsIcons else { return }
        for style in IconStyle.allCases {
            let r = iconRect(style)
            let box = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8)
            let isCurrent = style == IconStyle.saved
            (isCurrent ? NSColor.controlAccentColor.withAlphaComponent(0.3) : NSColor.labelColor.withAlphaComponent(isHovered(r) ? 0.16 : 0.06)).setFill()
            box.fill()
            if isCurrent {
                NSColor.controlAccentColor.setStroke()
                box.lineWidth = 1.5
                box.stroke()
            }
            // Template images draw black outside the menu bar: tint them like text.
            let icon = mascot(style, workspace: current, of: apps.count)
            let tinted = NSImage(size: icon.size, flipped: false) { rr in
                icon.draw(in: rr)
                NSColor.labelColor.set()
                rr.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: r.insetBy(dx: 7, dy: 7), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        let small = NSFont.systemFont(ofSize: 12)
        ((Self.showsShortcuts ? "▾  Shortcuts" : "▸  Shortcuts") as NSString).draw(
            at: NSPoint(x: toggleRect.minX + 4, y: toggleRect.minY + 1),
            withAttributes: [.font: small, .foregroundColor: NSColor.secondaryLabelColor])
        guard Self.showsShortcuts else { return }
        for (k, (keys, action)) in shortcuts.enumerated() {
            let y = linesTop + CGFloat(k) * Self.lineHeight
            (keys as NSString).draw(at: NSPoint(x: Self.pad + 18, y: y),
                                    withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.labelColor])
            (action as NSString).draw(at: NSPoint(x: Self.pad + 140, y: y),
                                      withAttributes: [.font: small, .foregroundColor: NSColor.secondaryLabelColor])
        }
    }
}
