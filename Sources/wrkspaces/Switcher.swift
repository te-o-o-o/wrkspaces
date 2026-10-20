import AppKit

/// Grid of the nine workspaces with their apps. Shown while ⌃ stays held after a workspace
/// shortcut (like Cmd-Tab), or from the menu bar icon. No fade: it appears and goes at once.
final class Switcher {
    private let panel: NSPanel
    let grid = GridView(frame: NSRect(origin: .zero, size: GridView.size))
    private var poll: Timer?
    private var outsideClick: Any?

    var isVisible: Bool { panel.isVisible }

    init() {
        grid.autoresizingMask = [.width, .height]
        panel = NSPanel(contentRect: grid.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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

    /// Centered, display only, gone when ⌃ is released.
    func showWhileControlHeld(_ apps: [[NSImage]], current: Int) {
        update(apps, current: current)
        guard !panel.isVisible else { return }
        resize(showsIcons: false)
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - panel.frame.width / 2, y: screen.frame.midY - panel.frame.height / 2))
        }
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        // ponytail: polls ⌃ at 20 Hz while visible instead of a global flagsChanged monitor.
        poll = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            if !NSEvent.modifierFlags.contains(.control) { self?.hide() }
        }
    }

    /// Under the menu bar icon, with the icon picker below the grid: click a workspace
    /// to go there, an icon to use it, anywhere else to close.
    func showBelow(_ anchor: NSRect, _ apps: [[NSImage]], current: Int) {
        update(apps, current: current)
        resize(showsIcons: true)
        var x = anchor.midX - panel.frame.width / 2
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor.origin) }) {
            x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - panel.frame.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: anchor.minY - panel.frame.height - 6))
        panel.ignoresMouseEvents = false
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
        panel.orderOut(nil)
    }

    private func resize(showsIcons: Bool) {
        grid.showsIcons = showsIcons
        panel.setContentSize(GridView.size(showsIcons: showsIcons))
    }

    private func update(_ apps: [[NSImage]], current: Int) {
        grid.apps = apps
        grid.current = current
        grid.needsDisplay = true
    }
}

final class GridView: NSView {
    static let tile = NSSize(width: 112, height: 76)
    static let gap: CGFloat = 10
    static let pad: CGFloat = 16
    static let iconBox: CGFloat = 32
    static let size = size(showsIcons: false)
    static func size(showsIcons: Bool) -> NSSize {
        NSSize(width: pad * 2 + tile.width * 3 + gap * 2,
               height: pad * 2 + tile.height * 3 + gap * 2 + (showsIcons ? iconBox + gap * 1.5 : 0))
    }

    var apps: [[NSImage]] = []  // per workspace, one icon per app
    var current = 1
    var showsIcons = false
    var onPick: ((Int) -> Void)?
    var onPickIcon: ((IconStyle) -> Void)?

    override var isFlipped: Bool { true }  // workspace 1 top-left, like a numpad read top-down

    // The panel never becomes key, so the first click must count.
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let i = apps.indices.first(where: { tileRect($0).contains(p) }) { onPick?(i + 1) }
        if showsIcons, let style = IconStyle.allCases.first(where: { iconRect($0).contains(p) }) { onPickIcon?(style) }
    }

    func iconRect(_ style: IconStyle) -> NSRect {
        let (box, gap) = (Self.iconBox, Self.gap)
        let k = CGFloat(IconStyle.allCases.firstIndex(of: style)!)
        let row = CGFloat(IconStyle.allCases.count) * (box + gap) - gap
        return NSRect(x: bounds.midX - row / 2 + k * (box + gap), y: tileRect(8).maxY + gap * 1.5, width: box, height: box)
    }

    func tileRect(_ i: Int) -> NSRect {
        let (tile, gap, pad) = (Self.tile, Self.gap, Self.pad)
        return NSRect(x: pad + CGFloat(i % 3) * (tile.width + gap), y: pad + CGFloat(i / 3) * (tile.height + gap),
                      width: tile.width, height: tile.height)
    }

    override func draw(_: NSRect) {
        for (i, icons) in apps.enumerated() {
            let r = tileRect(i)
            let box = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
            let isCurrent = i + 1 == current
            (isCurrent ? NSColor.controlAccentColor.withAlphaComponent(0.3) : NSColor.labelColor.withAlphaComponent(0.06)).setFill()
            box.fill()
            if isCurrent {
                NSColor.controlAccentColor.setStroke()
                box.lineWidth = 2
                box.stroke()
            }
            ("\(i + 1)" as NSString).draw(at: NSPoint(x: r.minX + 9, y: r.minY + 6), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: isCurrent ? NSColor.labelColor : NSColor.secondaryLabelColor,
            ])
            let shown = icons.prefix(3)  // 3 × 28 px is what a tile holds
            let side: CGFloat = 28
            var x = r.midX - (CGFloat(shown.count) * (side + 4) - 4) / 2
            for icon in shown {
                icon.draw(in: NSRect(x: x, y: r.maxY - side - 10, width: side, height: side), from: .zero,
                          operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                x += side + 4
            }
            if icons.count > 3 {
                ("+\(icons.count - 3)" as NSString).draw(at: NSPoint(x: r.maxX - 26, y: r.minY + 6), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.secondaryLabelColor,
                ])
            }
        }
        guard showsIcons else { return }
        for style in IconStyle.allCases {
            let r = iconRect(style)
            let box = NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8)
            let isCurrent = style == IconStyle.saved
            (isCurrent ? NSColor.controlAccentColor.withAlphaComponent(0.3) : NSColor.labelColor.withAlphaComponent(0.06)).setFill()
            box.fill()
            if isCurrent {
                NSColor.controlAccentColor.setStroke()
                box.lineWidth = 1.5
                box.stroke()
            }
            // Template images draw black outside the menu bar: tint them like text.
            let icon = mascot(style, workspace: current)
            let tinted = NSImage(size: icon.size, flipped: false) { rr in
                icon.draw(in: rr)
                NSColor.labelColor.set()
                rr.fill(using: .sourceAtop)
                return true
            }
            tinted.draw(in: r.insetBy(dx: 7, dy: 7), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}
