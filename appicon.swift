// Draws the app icon into an .iconset folder: the menu bar window, in white on teal.
// Run by bundle.sh (`swift appicon.swift <dir>.iconset`), then `iconutil` packs the .icns.
import AppKit

let teal = NSGradient(starting: NSColor(red: 0.55, green: 0.88, blue: 0.84, alpha: 1),
                      ending: NSColor(red: 0.13, green: 0.60, blue: 0.62, alpha: 1))!

func draw(_ size: CGFloat) {
    let k = size / 1024
    // macOS icon grid: an 824 px rounded square centered in 1024.
    teal.draw(in: NSBezierPath(roundedRect: NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k),
                               xRadius: 185 * k, yRadius: 185 * k), angle: -90)
    // Same shapes as the menu bar icon (Icon.swift), from its 18-unit grid.
    let s = 36 * k, ox = 512 * k - 9 * s, oy = 512 * k - 8.5 * s - 10 * k
    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s)
    }
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 30 * k
    shadow.shadowOffset = NSSize(width: 0, height: -12 * k)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.set()
    NSColor.white.setFill()
    let window = NSBezierPath(roundedRect: r(2, 2, 14, 13), xRadius: 3.5 * s, yRadius: 3.5 * s)
    window.append(NSBezierPath(roundedRect: r(3.5, 3.5, 11, 7.5), xRadius: 2 * s, yRadius: 2 * s).reversed)
    window.fill()
    NSGraphicsContext.restoreGraphicsState()  // also resets the fill color
    NSColor.white.setFill()
    for x in [6.5, 11.5] { NSBezierPath(ovalIn: r(x - 1.25, 5.25, 2.5, 2.5)).fill() }
}

let dir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(CGFloat(px))
        NSGraphicsContext.current = nil
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
    }
}
