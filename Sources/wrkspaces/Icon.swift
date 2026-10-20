import AppKit

/// Menu bar mascot: a little window with eyes. They look left on workspaces 1–3,
/// ahead on 4–6 and right on 7–9, a hint of where you are without any animation.
/// Template image, so macOS tints it for light and dark menu bars like its own icons.
func mascot(workspace n: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: 14, height: 13), xRadius: 3.5, yRadius: 3.5).fill()
        // Hollow out the window below its title bar.
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSBezierPath(roundedRect: NSRect(x: 3.5, y: 3.5, width: 11, height: 7.5), xRadius: 2, yRadius: 2).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        let look = CGFloat((n - 1) / 3 - 1) * 1.5
        for x in [6.5, 11.5] {
            NSBezierPath(ovalIn: NSRect(x: x - 1.25 + look, y: 5.25, width: 2.5, height: 2.5)).fill()
        }
        return true
    }
    image.isTemplate = true
    return image
}
