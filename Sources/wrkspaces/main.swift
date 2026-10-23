import AppKit
import Carbon.HIToolbox
import ServiceManagement
import WrkspacesCore

final class App: NSObject, NSApplicationDelegate {
    var ws = Workspaces<CGWindowID>()
    var elements: [CGWindowID: AXUIElement] = [:]  // latest AX element of each window
    var saved: [CGWindowID: CGPoint] = [:]  // real position of each hidden window
    var lastFocused: [Int: CGWindowID] = [:]
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let switcher = Switcher()

    var started = false

    func applicationDidFinishLaunching(_: Notification) {
        setUpStatusItem()
        if AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
            start()
            return
        }
        // Without access the icon still shows, with a menu that says what to do. macOS may
        // only report the grant to a fresh process: poll, and offer Relaunch for when it doesn't.
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            start()
        }
    }

    func start() {
        started = true
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
        recoverStrays()
        refresh()
        setUpStatusItem()
        switcher.grid.onPick = { [unowned self] n in
            switcher.hide()
            switchTo(n)
        }
        // The grid stays open to show the app in its new place.
        switcher.grid.onMoveApp = { [unowned self] pid, from, to in
            moveApp(pid, from: from, to: to)
            switcher.update(overview(), current: ws.current)
        }
        // The grid stays open so the new icon can be seen next to the others.
        switcher.grid.onPickIcon = { [unowned self] style in
            IconStyle.saved = style
            updateStatusItem()
            switcher.grid.needsDisplay = true
        }
        registerHotKeys { [unowned self] id in
            id > 100 ? moveFocused(to: Int(id) - 100) : switchTo(Int(id))
            // Like Cmd-Tab: a quick tap shows nothing, keeping ⌃ held shows the grid.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
                if NSEvent.modifierFlags.contains(.control) { switcher.showWhileControlHeld(overview(), current: ws.current) }
            }
        }
        // Cmd-Tab or a Dock click onto a window parked elsewhere: follow it.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [unowned self] _ in
            if let id = focusedWindow()?.windowID, let n = ws.workspace(of: id), n != ws.current { switchTo(n, focusing: id) }
        }
        updateStatusItem()
    }

    /// `focusing`: the window that brought us here (Cmd-Tab, AltTab, Dock), which must win
    /// over the one last used on that workspace.
    func switchTo(_ n: Int, focusing target: CGWindowID? = nil) {
        guard n != ws.current else { return }
        refresh()
        // When following an activation, the focused window already is the one from workspace n.
        if let id = focusedWindow()?.windowID, ws.workspace(of: id) == ws.current { lastFocused[ws.current] = id }
        let (hide, show) = ws.switchTo(n)
        hide.forEach(park)
        show.forEach(unpark)
        focusOrNothing(target ?? lastFocused[n].flatMap { show.contains($0) ? $0 : nil } ?? byRecency(show, stacking: stackingOrder()).first)
        updateStatusItem()
    }

    func moveFocused(to n: Int) {
        refresh()
        guard let id = focusedWindow()?.windowID, ws.move(id, to: n) else { return }
        park(id)
        focusOrNothing(byRecency(ws.windows(in: ws.current), stacking: stackingOrder()).first)
    }

    /// Dragged from the grid: every window of that app on workspace `from` goes to `n`.
    func moveApp(_ pid: pid_t, from: Int, to n: Int) {
        refresh()
        let ids = byRecency(ws.windows(in: from).filter { elements[$0]?.pid == pid }, stacking: stackingOrder())
        for id in ids where ws.move(id, to: n) { park(id) }  // left the visible workspace
        if n == ws.current {
            ids.forEach(unpark)
            focusOrNothing(ids.first)
        } else if from == ws.current {
            focusOrNothing(byRecency(ws.windows(in: ws.current), stacking: stackingOrder()).first)
        }
    }

    /// With no window left to focus, keystrokes would still go to the hidden one:
    /// take the focus ourselves, we have no window so typing goes nowhere.
    func focusOrNothing(_ id: CGWindowID?) {
        if let w = id.flatMap({ elements[$0] }) { focus(w) } else { NSApp.activate() }
    }

    func refresh() {
        elements = Dictionary(allWindows().compactMap { w in w.windowID.map { ($0, w) } }, uniquingKeysWith: { first, _ in first })
        ws.sync(Array(elements.keys))
        saved = saved.filter { elements[$0.key] != nil }
    }

    func park(_ id: CGWindowID) {
        guard let w = elements[id] else { return }
        if let p = w.position, !isHidden(p, screens: screens) { saved[id] = p }
        w.setPosition(hiddenCorner(screens: screens))
    }

    func unpark(_ id: CGWindowID) {
        elements[id]?.setPosition(saved.removeValue(forKey: id) ?? fallbackPosition())
    }

    /// Windows left in the corner by a crash: bring them back before anything else.
    func recoverStrays() {
        for w in allWindows() {
            if let p = w.position, isHidden(p, screens: screens) { w.setPosition(fallbackPosition()) }
        }
    }

    @objc func quit() {
        refresh()
        saved.forEach { elements[$0.key]?.setPosition($0.value) }
        recoverStrays()  // anything still parked that we lost track of
        NSApp.terminate(nil)
    }

    // MARK: menu bar

    func setUpStatusItem() {
        item.button?.imagePosition = .imageLeft
        // Monospaced digits so the item does not change width from 1 to 9.
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
    }

    func updateStatusItem() {
        item.button?.image = mascot(IconStyle.saved, workspace: ws.current)
        item.button?.title = started ? "\(ws.current)" : "!"
    }

    /// Left click toggles the grid under the icon, right click offers Quit.
    @objc func statusItemClicked() {
        if !started {
            let menu = NSMenu()
            menu.addItem(withTitle: "wrkspaces needs Accessibility access", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "").target = self
            if Bundle.main.bundleIdentifier != nil {
                menu.addItem(withTitle: "Relaunch wrkspaces", action: #selector(relaunch), keyEquivalent: "").target = self
            }
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit wrkspaces", action: #selector(quit), keyEquivalent: "q").target = self
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else if NSApp.currentEvent?.type == .rightMouseUp {
            switcher.hide()
            let menu = NSMenu()
            // Login items need a real .app: hidden under `swift run`.
            if Bundle.main.bundleIdentifier != nil {
                let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
                login.target = self
                login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            }
            menu.addItem(withTitle: "Quit wrkspaces", action: #selector(quit), keyEquivalent: "q").target = self
            // Attach the menu just for this click, or every left click would open it too.
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else if switcher.isVisible {
            switcher.hide()
        } else if let anchor = item.button?.window?.frame {
            switcher.showBelow(anchor, overview(), current: ws.current)
        }
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// A new process sees the freshly granted access; this one may never.
    @objc func relaunch() {
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", "sleep 0.5; open \"$0\"", Bundle.main.bundlePath]
        try? sh.run()
        NSApp.terminate(nil)
    }

    @objc func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("wrkspaces: open at login: \(error)")
        }
    }

    /// Apps of each workspace, one entry per app, the last used first.
    func overview() -> [[AppIcon]] {
        refresh()
        let stacking = stackingOrder()
        return (1...workspaceCount).map { n in
            var seen = Set<pid_t>()
            return byRecency(ws.windows(in: n), stacking: stacking)
                .compactMap { elements[$0]?.pid }
                .filter { seen.insert($0).inserted }
                .compactMap { pid in NSRunningApplication(processIdentifier: pid)?.icon.map { AppIcon(pid: pid, icon: $0) } }
        }
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

    // The keypad digits have their own key codes: register them too, numbered the same.
    let rows = [
        ("", [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]),
        (" (keypad)", [kVK_ANSI_Keypad1, kVK_ANSI_Keypad2, kVK_ANSI_Keypad3, kVK_ANSI_Keypad4, kVK_ANSI_Keypad5,
                       kVK_ANSI_Keypad6, kVK_ANSI_Keypad7, kVK_ANSI_Keypad8, kVK_ANSI_Keypad9]),
    ]
    for (label, keys) in rows {
        for (i, key) in keys.enumerated() {
            // id n = switch to n, id 100+n = move the focused window to n
            for (mods, base) in [(controlKey, 0), (controlKey | shiftKey, 100)] {
                var ref: EventHotKeyRef?
                let id = EventHotKeyID(signature: OSType(0x7772_6B73), id: UInt32(base + i + 1))  // 'wrks'
                if RegisterEventHotKey(UInt32(key), UInt32(mods), id, GetApplicationEventTarget(), 0, &ref) != noErr {
                    print("wrkspaces: shortcut \(base == 0 ? "⌃" : "⌃⇧")\(i + 1)\(label) is taken by another app")
                }
            }
        }
    }
}

// MARK: main

let app = App()
NSApplication.shared.delegate = app
NSApplication.shared.setActivationPolicy(.accessory)

// Ctrl-C in a terminal must not leave windows stranded in the corner.
let signalSources = [SIGINT, SIGTERM].map { sig in
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler { app.quit() }
    src.resume()
    return src
}

NSApplication.shared.run()
