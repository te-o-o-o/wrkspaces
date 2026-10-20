import AppKit
import Carbon.HIToolbox
import WrkspacesCore

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var ws = Workspaces<AXUIElement>()
    var saved: [AXUIElement: CGPoint] = [:]  // real position of each hidden window
    var lastFocused: [Int: AXUIElement] = [:]
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let switcher = Switcher()

    func applicationDidFinishLaunching(_: Notification) {
        recoverStrays()
        ws.sync(allWindows())
        buildMenu()
        registerHotKeys { [unowned self] id in
            id > 100 ? moveFocused(to: Int(id) - 100) : switchTo(Int(id))
            // Like Cmd-Tab: a quick tap shows nothing, keeping ⌃ held shows the grid.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                if NSEvent.modifierFlags.contains(.control) { switcher.show(overview(), current: ws.current) }
            }
        }
        // Cmd-Tab or a Dock click onto a window parked elsewhere: follow it.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [unowned self] _ in
            if let w = focusedWindow(), let n = ws.workspace(of: w), n != ws.current { switchTo(n) }
        }
    }

    func switchTo(_ n: Int) {
        guard n != ws.current else { return }
        refresh()
        lastFocused[ws.current] = focusedWindow()
        let (hide, show) = ws.switchTo(n)
        hide.forEach(park)
        show.forEach(unpark)
        if let w = lastFocused[n].flatMap({ show.contains($0) ? $0 : nil }) ?? show.first { focus(w) }
        updateMenu()
    }

    func moveFocused(to n: Int) {
        refresh()
        guard let w = focusedWindow(), ws.move(w, to: n) else { return }
        park(w)
        if let next = ws.windows(in: ws.current).first { focus(next) }
    }

    func refresh() {
        ws.sync(allWindows())
        saved = saved.filter { ws.workspace(of: $0.key) != nil }
    }

    func park(_ w: AXUIElement) {
        if let p = w.position, !isHidden(p, screens: screens) { saved[w] = p }
        w.setPosition(hiddenCorner(screens: screens))
    }

    func unpark(_ w: AXUIElement) {
        w.setPosition(saved.removeValue(forKey: w) ?? fallbackPosition())
    }

    /// Windows left in the corner by a crash: bring them back before anything else.
    func recoverStrays() {
        for w in allWindows() {
            if let p = w.position, isHidden(p, screens: screens) { w.setPosition(fallbackPosition()) }
        }
    }

    @objc func quit() {
        saved.forEach { $0.key.setPosition($0.value) }
        NSApp.terminate(nil)
    }

    // MARK: menu bar

    func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        updateMenu()
    }

    /// Windows of each workspace, sorted by app then title.
    func overview() -> [[WindowInfo]] {
        refresh()
        return (1...workspaceCount).map { ws.windows(in: $0).map(WindowInfo.init).sorted { $0.label < $1.label } }
    }

    /// Rebuilt on every open, so it shows where each window is right now.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for (i, windows) in overview().enumerated() {
            let n = i + 1
            let row = menu.addItem(withTitle: windows.isEmpty ? "\(n)  —" : "\(n)", action: #selector(pick(_:)), keyEquivalent: "")
            row.target = self
            row.tag = n
            row.state = n == ws.current ? .on : .off
            for w in windows {
                let wi = menu.addItem(withTitle: w.label, action: #selector(pickWindow(_:)), keyEquivalent: "")
                wi.target = self
                wi.indentationLevel = 1
                wi.image = w.icon
                wi.representedObject = w.window
            }
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit wrkspaces", action: #selector(quit), keyEquivalent: "q").target = self
    }

    @objc func pick(_ sender: NSMenuItem) { switchTo(sender.tag) }

    @objc func pickWindow(_ sender: NSMenuItem) {
        let w = sender.representedObject as! AXUIElement
        if let n = ws.workspace(of: w) { switchTo(n) }
        focus(w)
    }

    func updateMenu() {
        item.button?.image = mascot(workspace: ws.current)
        item.button?.imagePosition = .imageLeft
        // Monospaced digits so the item does not change width from 1 to 9.
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        item.button?.title = "\(ws.current)"
    }
}

// MARK: hotkeys
// Carbon's RegisterEventHotKey still is the only global-shortcut API that needs no
// extra permission. Key codes are physical, so ⌃1 is the same key on AZERTY and QWERTY.

var onHotKey: ((UInt32) -> Void)?

func registerHotKeys(_ handler: @escaping (UInt32) -> Void) {
    onHotKey = handler
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
        var id = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
        onHotKey?(id.id)
        return noErr
    }, 1, &spec, nil, nil)

    let keys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
    for (i, key) in keys.enumerated() {
        // id n = switch to n, id 100+n = move the focused window to n
        for (mods, base) in [(controlKey, 0), (controlKey | shiftKey, 100)] {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x7772_6B73), id: UInt32(base + i + 1))  // 'wrks'
            if RegisterEventHotKey(UInt32(key), UInt32(mods), id, GetApplicationEventTarget(), 0, &ref) != noErr {
                print("wrkspaces: shortcut \(base == 0 ? "⌃" : "⌃⇧")\(i + 1) is taken by another app")
            }
        }
    }
}

// MARK: main

guard AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) else {
    print("wrkspaces: grant Accessibility access (System Settings > Privacy & Security > Accessibility), then relaunch.")
    exit(1)
}
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)

let app = App()
NSApplication.shared.delegate = app
NSApplication.shared.setActivationPolicy(.accessory)

// Ctrl-C in a terminal must not leave windows stranded in the corner.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { app.quit() }
    src.resume()
    signalSources.append(src)
}

NSApplication.shared.run()
