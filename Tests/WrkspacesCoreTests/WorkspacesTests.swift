import Testing
import WrkspacesCore

@Test func newWindowsLandOnCurrentWorkspace() {
    var ws = Workspaces<Int>()
    ws.sync([1, 2])
    _ = ws.switchTo(3)
    ws.sync([1, 2, 3])
    #expect(ws.workspace(of: 1) == 1)
    #expect(ws.workspace(of: 3) == 3)
}

@Test func closedWindowsAreForgotten() {
    var ws = Workspaces<Int>()
    ws.sync([1, 2])
    ws.sync([2])
    #expect(ws.workspace(of: 1) == nil)
}

@Test func switchHidesCurrentAndShowsTarget() {
    var ws = Workspaces<Int>()
    ws.sync([1, 2])
    let moved = ws.move(2, to: 2)
    let (hide, show) = ws.switchTo(2)
    #expect(moved)
    #expect(hide == [1])
    #expect(show == [2])
    #expect(ws.current == 2)
}

@Test func switchToSameOrInvalidIsNoop() {
    var ws = Workspaces<Int>()
    ws.sync([1])
    for n in [1, 0, 10] {
        let hide = ws.switchTo(n).hide
        #expect(hide.isEmpty)
    }
    #expect(ws.current == 1)
}

@Test func moveOnlyHidesWhenLeavingVisibleWorkspace() {
    var ws = Workspaces<Int>()
    ws.sync([1])
    let results = [ws.move(1, to: 1), ws.move(1, to: 4), ws.move(1, to: 5), ws.move(99, to: 2)]
    #expect(results == [false, true, false, false])
}

@Test func windowsKeepTheirWorkspaceAcrossSwitches() {
    var ws = Workspaces<Int>()
    ws.sync([1, 2])
    _ = ws.move(2, to: 3)
    _ = ws.switchTo(3)
    let back = ws.switchTo(1)
    #expect(back.hide == [2])
    #expect(back.show == [1])
}

@Test func windowsInListsWorkspaceContent() {
    var ws = Workspaces<Int>()
    ws.sync([1, 2, 3])
    _ = ws.move(3, to: 9)
    #expect(ws.windows(in: 1) == [1, 2])
    #expect(ws.windows(in: 9) == [3])
    #expect(ws.windows(in: 5).isEmpty)
}

@Test func moveToInvalidWorkspaceIsRefused() {
    var ws = Workspaces<Int>()
    ws.sync([1])
    let results = [ws.move(1, to: 0), ws.move(1, to: 10)]
    #expect(results == [false, false])
    #expect(ws.workspace(of: 1) == 1)
}

@Test func byRecencyFollowsStackingOrderAndPutsUnknownLast() {
    #expect(byRecency([1, 2, 3, 4], stacking: [3, 9, 1]) == [3, 1, 2, 4])
}

@Test func windowsKeepTheirArrivalOrderAndAMovedOneArrivesLast() {
    var ws = Workspaces<Int>()
    ws.sync([3, 1, 2])
    ws.sync([2, 4, 1, 3])  // listed in another order: no reshuffle, the new one goes last
    #expect(ws.windows(in: 1) == [3, 1, 2, 4])
    _ = ws.move(3, to: 2)
    _ = ws.move(3, to: 1)
    #expect(ws.windows(in: 1) == [1, 2, 4, 3])
}

@Test func nextAppFollowsTheOrderAndWrapsAround() {
    #expect(nextApp(["a", "b", "c"], after: "a") == "b")
    #expect(nextApp(["a", "b", "c"], after: "c") == "a")
    #expect(nextApp(["a", "b", "c"], after: "z") == "a")  // gone meanwhile: start at the first
    #expect(nextApp(["a", "b", "c"], after: nil) == "a")  // new hold: the first
    #expect(nextApp([String](), after: "a") == nil)
}

@Test func placeMovesAnAppsWindowsBeforeAnotherOrLast() {
    var ws = Workspaces<Int>()
    ws.sync([1, 2, 3, 4])
    ws.place([4, 2], before: 1)
    #expect(ws.windows(in: 1) == [2, 4, 1, 3])  // kept in their own order
    ws.place([2], before: nil)
    #expect(ws.windows(in: 1) == [4, 1, 3, 2])
}
