import CoreGraphics

/// What is remembered of a window to put it back on its workspace after a relaunch, of
/// wrkspaces or of its app. Window ids change when an app restarts, so a window is
/// recognised by what survives: its title and its frame.
public struct Memo: Codable, Equatable {
    public var app: String  // bundle identifier
    public var window: UInt32  // CGWindowID: still valid when only wrkspaces restarted
    public var title: String
    public var frame: CGRect  // its real place, never the parking corner
    public var workspace: Int

    public init(app: String, window: UInt32, title: String, frame: CGRect, workspace: Int) {
        (self.app, self.window, self.title, self.frame, self.workspace) = (app, window, title, frame, workspace)
    }
}

/// Remembered windows waiting for theirs to come back. Each memo is claimed once, so two
/// windows of one app never take the same place.
public struct Places {
    public var memos: [Memo]

    public init(_ memos: [Memo] = []) { self.memos = memos }

    /// The memo of a window seen for the first time: same id (the app kept running), else, while
    /// its app is `restoring` (just launched), same title, then same frame, then, if the app has
    /// no other window yet, any memo of the app: one that reopens a single blank window still
    /// belongs where it was. Outside `restoring`, a ⌘N window titled like an old one stays put.
    // ponytail: two windows of one app with the same title and the same frame may swap
    // workspaces; the AX document or the tab URLs would tell them apart.
    public mutating func claim(app: String, window: UInt32, title: String, frame: CGRect,
                               restoring: Bool, appHasOtherWindows: Bool) -> Memo? {
        let mine = memos.indices.filter { memos[$0].app == app }
        var i = mine.first { memos[$0].window == window }
        if i == nil, restoring {
            i = (title.isEmpty ? nil : mine.first { memos[$0].title == title })
                ?? mine.first { sameFrame(memos[$0].frame, frame) }
                ?? (appHasOtherWindows ? nil : mine.first)
        }
        return i.map { memos.remove(at: $0) }
    }
}

/// Apps put windows back within a pixel or two of where they were.
func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
}
