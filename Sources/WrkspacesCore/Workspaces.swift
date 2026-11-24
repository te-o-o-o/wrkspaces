public let workspaceCount = 9

/// Which window lives on which workspace. Knows nothing about AX or AppKit,
/// so `W` is any window handle (an AXUIElement in the app, an Int in tests).
public struct Workspaces<W: Hashable> {
    public private(set) var current = 1
    private var home: [W: Int] = [:]
    private var arrival: [W] = []  // every window, in the order it reached its workspace

    public init() {}

    /// New windows land on the current workspace, after the others; closed ones are forgotten.
    public mutating func sync(_ alive: [W]) {
        let set = Set(alive)
        home = home.filter { set.contains($0.key) }
        arrival = arrival.filter { set.contains($0) }
        for w in alive where home[w] == nil {
            home[w] = current
            arrival.append(w)
        }
    }

    public func workspace(of w: W) -> Int? { home[w] }

    /// In arrival order, so a workspace keeps its apps in the same order whatever gets focused.
    public func windows(in n: Int) -> [W] { arrival.filter { home[$0] == n } }

    /// Returns the windows to hide and the ones to show.
    public mutating func switchTo(_ n: Int) -> (hide: [W], show: [W]) {
        guard n != current, (1...workspaceCount).contains(n) else { return ([], []) }
        let hide = windows(in: current)
        current = n
        return (hide, windows(in: n))
    }

    /// Returns true when the window leaves the visible workspace and must be hidden.
    /// It arrives last on its new workspace.
    public mutating func move(_ w: W, to n: Int) -> Bool {
        guard (1...workspaceCount).contains(n), let from = home[w], from != n else { return false }
        home[w] = n
        arrival.removeAll { $0 == w }
        arrival.append(w)
        return from == current
    }

    /// Reorders a workspace: `windows` (one app's) go right before `target`, or last when it is nil.
    public mutating func place(_ windows: [W], before target: W?) {
        let moving = Set(windows)
        let kept = arrival.filter { !moving.contains($0) }
        let i = target.flatMap { kept.firstIndex(of: $0) } ?? kept.endIndex
        // Both slices wrapped: the CI's older Swift will not add an ArraySlice to an Array.
        arrival = Array(kept[..<i]) + arrival.filter { moving.contains($0) } + Array(kept[i...])
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
