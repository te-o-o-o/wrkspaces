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

// The one private call: AX has no public way from a window element to its CGWindowID.
// Window managers all rely on it (AeroSpace, yabai, Rectangle) and it needs no SIP change.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {
    /// Stable for the window's whole life, unlike the element: an app may hand out a new one.
    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(self, &id) == .success ? id : nil
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

/// Asked to AX live: NSWorkspace.frontmostApplication is only refreshed by our run loop,
/// so a shortcut pressed right after switching apps would act on the previous one.
func focusedWindow() -> AXUIElement? {
    guard let app: AXUIElement = AXUIElementCreateSystemWide().get(kAXFocusedApplicationAttribute) else { return nil }
    return app.get(kAXFocusedWindowAttribute)
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
