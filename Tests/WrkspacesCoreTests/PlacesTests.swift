import CoreGraphics
import Testing
import WrkspacesCore

let left = CGRect(x: 0, y: 33, width: 800, height: 900)
let right = CGRect(x: 800, y: 33, width: 700, height: 900)

// Zen with one window on workspace 1 and one on 3, as saved when wrkspaces quit.
func zen() -> Places {
    Places([
        Memo(app: "zen", window: 10, title: "Mail", frame: left, workspace: 1),
        Memo(app: "zen", window: 11, title: "Docs", frame: right, workspace: 3),
    ])
}

@Test func onlyWrkspacesRestartedSoIdsMatch() {
    var p = zen()
    // Same ids, even with titles that changed meanwhile.
    #expect(p.claim(app: "zen", window: 11, title: "Other", frame: .zero, restoring: true, appHasOtherWindows: false)?.workspace == 3)
    #expect(p.claim(app: "zen", window: 10, title: "Other", frame: .zero, restoring: true, appHasOtherWindows: true)?.workspace == 1)
    #expect(p.memos.isEmpty)
}

@Test func relaunchedAppIsRecognisedByTitleThenFrame() {
    var p = zen()
    // New ids. The window back on the right, titled "Docs", goes to 3; the other one, whose
    // title changed, is recognised by its frame.
    #expect(p.claim(app: "zen", window: 50, title: "Docs", frame: right, restoring: true, appHasOtherWindows: false)?.workspace == 3)
    #expect(p.claim(app: "zen", window: 51, title: "Inbox (2)", frame: left, restoring: true, appHasOtherWindows: true)?.workspace == 1)
}

@Test func eachMemoIsClaimedOnce() {
    var p = zen()
    #expect(p.claim(app: "zen", window: 50, title: "Docs", frame: right, restoring: true, appHasOtherWindows: false)?.workspace == 3)
    // A second "Docs" window takes the memo left, through the app's fallback, not the same one.
    #expect(p.claim(app: "zen", window: 51, title: "Docs", frame: right, restoring: true, appHasOtherWindows: false)?.workspace == 1)
    #expect(p.claim(app: "zen", window: 52, title: "Docs", frame: right, restoring: true, appHasOtherWindows: false) == nil)
}

@Test func blankWindowOfARelaunchedAppGoesWhereTheAppWas() {
    var p = zen()
    #expect(p.claim(app: "zen", window: 50, title: "", frame: .zero, restoring: true, appHasOtherWindows: false)?.workspace == 1)
    // A second unknown window of the same app is a new one: it stays where we are.
    #expect(p.claim(app: "zen", window: 51, title: "", frame: .zero, restoring: true, appHasOtherWindows: true) == nil)
}

@Test func newWindowLaterIsNeverSentAway() {
    var p = zen()
    // ⌘N long after launch, titled like a remembered window: it stays on the current workspace.
    #expect(p.claim(app: "zen", window: 50, title: "Docs", frame: right, restoring: false, appHasOtherWindows: true) == nil)
    #expect(p.claim(app: "mail", window: 10, title: "Mail", frame: left, restoring: true, appHasOtherWindows: false) == nil)  // another app
}

@Test func restoredWindowsLandOnTheirWorkspace() {
    var ws = Workspaces<Int>(count: 6)
    ws.sync([1])
    let elsewhere = ws.sync([1, 2, 3, 4]) { [2: 3, 3: 1, 4: 9][$0] }
    #expect(elsewhere == [2, 4])  // 3 is on the current workspace, shown
    #expect(ws.windows(in: 3) == [2])
    #expect(ws.windows(in: 6) == [4])  // remembered on 9, only 6 now: the last one
    #expect(ws.windows(in: 1) == [1, 3])
}
