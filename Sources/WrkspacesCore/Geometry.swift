import CoreGraphics

// Screen frames come from NSScreen: bottom-left origin, the first one is the primary screen.
// Window positions are AX ones: top-left origin on the primary screen, y going down.

/// Bottom-right corner of all screens combined. macOS refuses a fully off-screen window,
/// so hidden windows sit there with a sliver still on screen (AeroSpace's trick).
public func hiddenCorner(screens: [CGRect]) -> CGPoint {
    let primaryHeight = screens[0].height
    let maxX = screens.map(\.maxX).max()!
    let maxY = screens.map { primaryHeight - $0.minY }.max()!
    return CGPoint(x: maxX - 1, y: maxY - 1)
}

// ponytail: a left edge within 50 px of the far right means "hidden by us"; a stored
// list of hidden windows would be exact if a real window ever ends up there.
// Only x is checked: macOS clamps the parked y to keep part of the title bar reachable.
public func isHidden(_ p: CGPoint, screens: [CGRect]) -> Bool { p.x > hiddenCorner(screens: screens).x - 50 }

/// Where a window goes back when its real position is lost (crash recovery):
/// top-left of the primary screen, under the menu bar.
public func fallbackPosition(primary: CGRect, visible: CGRect) -> CGPoint {
    CGPoint(x: visible.minX + 40, y: primary.height - visible.maxY + 40)
}
