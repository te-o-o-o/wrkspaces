import AppKit
import WrkspacesCore

/// Menu bar icons, picked from the right-click menu. All are template images, so macOS
/// tints them for light and dark menu bars like its own icons, and none is animated.
enum IconStyle: String, CaseIterable {
    case window, blob, flower, ring

    static let defaultsKey = "icon"

    static var saved: IconStyle {
        get { UserDefaults.standard.string(forKey: defaultsKey).flatMap(IconStyle.init) ?? .window }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }
}

func mascot(_ style: IconStyle, workspace n: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        switch style {
        case .window: drawWindow(n)
        case .blob: drawBlob(n)
        case .flower: drawFlower(n)
        case .ring: drawRing(n)
        }
        return true
    }
    image.isTemplate = true
    return image
}

private let center = NSPoint(x: 9, y: 9)

/// Eyes look left on workspaces 1–3, ahead on 4–6 and right on 7–9.
private func lookOffset(_ n: Int) -> CGFloat { CGFloat((n - 1) / 3 - 1) * 1.5 }

private func punch(_ draw: () -> Void) {
    NSGraphicsContext.current?.compositingOperation = .destinationOut
    draw()
    NSGraphicsContext.current?.compositingOperation = .sourceOver
}

/// A little window with eyes.
private func drawWindow(_ n: Int) {
    NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 14, height: 13), xRadius: 3.5, yRadius: 3.5).fill()
    // Hollow out the window below its title bar.
    punch { NSBezierPath(roundedRect: NSRect(x: 3.5, y: 3.5, width: 11, height: 7.5), xRadius: 2, yRadius: 2).fill() }
    for x in [6.5, 11.5] {
        NSBezierPath(ovalIn: NSRect(x: x - 1.25 + lookOffset(n), y: 5.25, width: 2.5, height: 2.5)).fill()
    }
}

/// A round blob with punched-out eyes.
private func drawBlob(_ n: Int) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: 2, y: 2.5))
    p.curve(to: NSPoint(x: 9, y: 15.5), controlPoint1: NSPoint(x: 1, y: 10), controlPoint2: NSPoint(x: 4, y: 15.5))
    p.curve(to: NSPoint(x: 16, y: 2.5), controlPoint1: NSPoint(x: 14, y: 15.5), controlPoint2: NSPoint(x: 17, y: 10))
    p.close()
    p.fill()
    punch {
        for x in [6.5, 11.5] {
            NSBezierPath(ovalIn: NSRect(x: x - 1.5 + lookOffset(n), y: 6, width: 3, height: 3)).fill()
        }
    }
}

/// Nine petals, one per workspace: 1 at the top, then clockwise. The current one is solid,
/// the others faint (template images only have alpha to play with).
private func drawFlower(_ n: Int) {
    for i in 0..<workspaceCount {
        let t = NSAffineTransform()
        t.translateX(by: center.x, yBy: center.y)
        t.rotate(byDegrees: 90 - CGFloat(i) * 40)
        let petal = NSBezierPath(ovalIn: NSRect(x: 2, y: -1.9, width: 6.8, height: 3.8))
        petal.transform(using: t as AffineTransform)
        NSColor.black.withAlphaComponent(i + 1 == n ? 1 : 0.3).setFill()
        petal.fill()
    }
    NSColor.black.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 1.7, y: center.y - 1.7, width: 3.4, height: 3.4)).fill()
}

/// Nine ring segments, the first n of them thick.
private func drawRing(_ n: Int) {
    for i in 0..<workspaceCount {
        let start = 90 - CGFloat(i) * 40 - 3
        let p = NSBezierPath()
        p.appendArc(withCenter: center, radius: 6.5, startAngle: start, endAngle: start - 34, clockwise: true)
        p.lineWidth = i < n ? 3 : 1
        p.lineCapStyle = .round
        p.stroke()
    }
}
