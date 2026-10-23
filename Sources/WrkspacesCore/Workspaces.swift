public let workspaceCount = 9

/// Which window lives on which workspace. Knows nothing about AX or AppKit,
/// so `W` is any window handle (an AXUIElement in the app, an Int in tests).
public struct Workspaces<W: Hashable> {
    public private(set) var current = 1
    private var home: [W: Int] = [:]

    public init() {}

    /// New windows land on the current workspace; closed ones are forgotten.
    public mutating func sync(_ alive: [W]) {
        let alive = Set(alive)
        home = home.filter { alive.contains($0.key) }
        for w in alive where home[w] == nil { home[w] = current }
    }

    public func workspace(of w: W) -> Int? { home[w] }

    public func windows(in n: Int) -> [W] { home.filter { $0.value == n }.map(\.key) }

    /// Returns the windows to hide and the ones to show.
    public mutating func switchTo(_ n: Int) -> (hide: [W], show: [W]) {
        guard n != current, (1...workspaceCount).contains(n) else { return ([], []) }
        let hide = windows(in: current)
        current = n
        return (hide, windows(in: n))
    }

    /// Returns true when the window leaves the visible workspace and must be hidden.
    public mutating func move(_ w: W, to n: Int) -> Bool {
        guard (1...workspaceCount).contains(n), let from = home[w], from != n else { return false }
        home[w] = n
        return from == current
    }
}

/// `windows` in the order they appear in `order` (the window server's stacking, front to
/// back, so the last used first); windows missing from it go last. `first`, when among
/// them, leads: a window sent to a hidden workspace is parked behind the others, yet it
/// is the one that workspace should show on top.
public func byRecency<W: Hashable>(_ windows: [W], stacking order: [W], first: W? = nil) -> [W] {
    let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
    return windows.sorted { a, b in
        if a == first || b == first { return a == first && b != first }
        return rank[a, default: .max] < rank[b, default: .max]
    }
}
