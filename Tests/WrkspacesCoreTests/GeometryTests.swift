import CoreGraphics
import Testing
import WrkspacesCore

let laptop = CGRect(x: 0, y: 0, width: 1512, height: 982)

@Test func cornerOfASingleScreen() {
    #expect(hiddenCorner(screens: [laptop]) == CGPoint(x: 1511, y: 981))
}

@Test func cornerGoesPastAScreenOnTheRight() {
    let right = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
    #expect(hiddenCorner(screens: [laptop, right]).x == 4071)  // 1512 + 2560 - 1
}

@Test func cornerGoesBelowAScreenUnderneath() {
    // NSScreen y grows upwards: a screen below the laptop has a negative minY.
    let below = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
    #expect(hiddenCorner(screens: [laptop, below]) == CGPoint(x: 1919, y: 2061))  // 982 + 1080 - 1
}

@Test func parkedWindowsAreSeenAsHidden() {
    // Positions measured on a real laptop: macOS clamps y, x stays where we put it.
    #expect(isHidden(CGPoint(x: 1511, y: 885), screens: [laptop]))
    #expect(isHidden(CGPoint(x: 1511, y: 865), screens: [laptop]))
}

@Test func normalWindowsAreNotHidden() {
    #expect(!isHidden(CGPoint(x: 0, y: 33), screens: [laptop]))
    #expect(!isHidden(CGPoint(x: 1400, y: 500), screens: [laptop]))
}

@Test func fallbackSitsUnderTheMenuBar() {
    let visible = CGRect(x: 0, y: 0, width: 1512, height: 949)  // 33 px menu bar on top
    #expect(fallbackPosition(primary: laptop, visible: visible) == CGPoint(x: 40, y: 73))
}
