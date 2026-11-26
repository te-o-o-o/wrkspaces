/// ⌃1 … ⌃9: never more workspaces than digits.
public let maxWorkspaces = 9

/// Which window lives on which workspace. Knows nothing about AX or AppKit,
/// so `W` is any window handle (an AXUIElement in the app, an Int in tests).
public struct Workspaces<W: Hashable> {
    public private(set) var current = 1
    public private(set) var count: Int
    private var home: [W: Int] = [:]
    private var arrival: [W] = []  // every window, in the order it reached its workspace

    public init(count: Int = maxWorkspaces) { self.count = min(max(count, 1), maxWorkspaces) }

    /// New windows land on `place(w)` when it names one (remembered from before a relaunch),
    /// on the current workspace otherwise, after the others; closed ones are forgotten.
    /// Returns the new windows that landed on another workspace: they must be hidden.
    @discardableResult
    public mutating func sync(_ alive: [W], place: (W) -> Int? = { _ in nil }) -> [W] {
        let set = Set(alive)
        home = home.filter { set.contains($0.key) }
        arrival = arrival.filter { set.contains($0) }
        var elsewhere: [W] = []
        for w in alive where home[w] == nil {
            // A workspace dropped since (fewer of them now) sends it to the last one.
            let n = place(w).map { min(max($0, 1), count) } ?? current
            home[w] = n
            arrival.append(w)
            if n != current { elsewhere.append(w) }
        }
        return elsewhere
    }

    public func workspace(of w: W) -> Int? { home[w] }

    /// In arrival order, so a workspace keeps its apps in the same order whatever gets focused.
    public func windows(in n: Int) -> [W] { arrival.filter { home[$0] == n } }

    /// Returns the windows to hide and the ones to show.
    public mutating func switchTo(_ n: Int) -> (hide: [W], show: [W]) {
        guard n != current, (1...count).contains(n) else { return ([], []) }
        let hide = windows(in: current)
        current = n
        return (hide, windows(in: n))
    }

    /// Returns true when the window leaves the visible workspace and must be hidden.
    /// It arrives last on its new workspace.
    public mutating func move(_ w: W, to n: Int) -> Bool {
        guard (1...count).contains(n), let from = home[w], from != n else { return false }
        home[w] = n
        arrival.removeAll { $0 == w }
        arrival.append(w)
        return from == current
    }

    /// Fewer workspaces: the windows of the dropped ones go to the new last one, after its own,
    /// and if we were on a dropped one we land there with them. Returns the windows to show.
    public mutating func setCount(_ k: Int) -> [W] {
        let k = min(max(k, 1), maxWorkspaces)
        let before = Set(windows(in: current))
        let dropped = arrival.filter { home[$0, default: 0] > k }
        for w in dropped { home[w] = k }
        let moving = Set(dropped)
        arrival = arrival.filter { !moving.contains($0) } + dropped
        count = k
        current = min(current, k)
        return windows(in: current).filter { !before.contains($0) }
    }

}

/// The order of the apps on each workspace, kept apart from their windows: windows come and go
/// (a tab closed and reopened, a window missed by one slow AX read, the app relaunched), the
/// app keeps its place. Saved with the windows' places, so it survives a relaunch too.
public struct AppOrder<A: Hashable> {
    public private(set) var order: [Int: [A]]

    public init(_ order: [Int: [A]] = [:]) { self.order = order }

    /// `present`: the apps with a window on workspace n. Known ones keep their place, new ones
    /// go last, in the order given.
    public mutating func apps(in n: Int, present: [A]) -> [A] {
        var list = order[n, default: []]
        for a in present where !list.contains(a) { list.append(a) }
        order[n] = list
        let here = Set(present)
        return list.filter(here.contains)
    }

    /// Dragged in the grid: `a` goes right before `b`, or last when it is nil.
    public mutating func place(_ a: A, before b: A?, in n: Int) {
        var list = order[n, default: []].filter { $0 != a }
        list.insert(a, at: b.flatMap { list.firstIndex(of: $0) } ?? list.endIndex)
        order[n] = list
    }
}

/// `windows` in the order they appear in `order` (the window server's stacking, front to
/// back, so the last used first); windows missing from it go last.
public func byRecency<W: Hashable>(_ windows: [W], stacking order: [W]) -> [W] {
    let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    return windows.sorted { rank[$0, default: .max] < rank[$1, default: .max] }
}

/// ⌃N on the workspace already shown: the app after the selected one, the first when none is
/// selected yet, back to the first after the last. `apps` are in the workspace's fixed order,
/// so three presses land on the third.
public func nextApp<A: Equatable>(_ apps: [A], after focused: A?) -> A? {
    guard !apps.isEmpty else { return nil }
    let i = focused.flatMap { apps.firstIndex(of: $0) } ?? -1
    return apps[(i + 1) % apps.count]
}
