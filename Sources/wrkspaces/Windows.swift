import AppKit
import WrkspacesCore

// Thin layer over the Accessibility API. Every call goes through AX, so a hung app
// would block us for the default 6 s: the timeout is lowered once in main.swift.

extension AXUIElement {
    func get<T>(_ attr: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attr as CFString, &v) == .success else { return nil }
        return v as? T
    }

    var position: CGPoint? {
        guard let v: AXValue = get(kAXPositionAttribute) else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(v, .cgPoint, &p) ? p : nil
    }

    func setPosition(_ p: CGPoint) {
        var p = p
        AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
    }

    var pid: pid_t {
        var pid: pid_t = 0
        AXUIElementGetPid(self, &pid)
        return pid
    }
}

/// Standard, visible windows of every regular app. Minimized and native full-screen
/// windows are skipped: they live outside our workspaces.
func allWindows() -> [AXUIElement] {
    NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }
        .flatMap { app -> [AXUIElement] in
            AXUIElementCreateApplication(app.processIdentifier).get(kAXWindowsAttribute) ?? []
        }
        .filter {
            ($0.get(kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole
                && ($0.get(kAXMinimizedAttribute) as Bool?) != true
                && ($0.get("AXFullScreen") as Bool?) != true
        }
}

func focusedWindow() -> AXUIElement? {
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
    return AXUIElementCreateApplication(app.processIdentifier).get(kAXFocusedWindowAttribute)
}

func focus(_ w: AXUIElement) {
    AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(w, kAXRaiseAction as CFString)
    NSRunningApplication(processIdentifier: w.pid)?.activate()
}

var screens: [CGRect] { NSScreen.screens.map(\.frame) }

func fallbackPosition() -> CGPoint {
    fallbackPosition(primary: NSScreen.screens[0].frame, visible: NSScreen.screens[0].visibleFrame)
}

/// What the menu and the switcher show about a window.
struct WindowInfo {
    let window: AXUIElement
    let appName: String
    let title: String
    let icon: NSImage?

    init(_ w: AXUIElement) {
        let app = NSRunningApplication(processIdentifier: w.pid)
        window = w
        appName = app?.localizedName ?? "?"
        title = w.get(kAXTitleAttribute) ?? ""
        icon = app?.icon.map {
            let i = $0.copy() as! NSImage
            i.size = NSSize(width: 16, height: 16)
            return i
        }
    }

    var label: String { title.isEmpty || title == appName ? appName : "\(appName) — \(title.prefix(50))" }
}
