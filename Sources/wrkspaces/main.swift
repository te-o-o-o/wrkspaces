import AppKit
import Carbon.HIToolbox
import ServiceManagement
import WrkspacesCore

final class App: NSObject, NSApplicationDelegate {
    var ws = Workspaces<AXUIElement>()
    var saved: [AXUIElement: CGPoint] = [:]  // real position of each hidden window
    var lastFocused: [Int: AXUIElement] = [:]
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let switcher = Switcher()

    func applicationDidFinishLaunching(_: Notification) {
        recoverStrays()
        ws.sync(allWindows())
        setUpStatusItem()
        switcher.grid.onPick = { [unowned self] n in
            switcher.hide()
            switchTo(n)
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
        focusOrNothing(lastFocused[n].flatMap { show.contains($0) ? $0 : nil } ?? show.first)
        updateStatusItem()
    }

    func moveFocused(to n: Int) {
        refresh()
        guard let w = focusedWindow(), ws.move(w, to: n) else { return }
        park(w)
        focusOrNothing(ws.windows(in: ws.current).first)
    }

    /// With no window left to focus, keystrokes would still go to the hidden one:
    /// take the focus ourselves, we have no window so typing goes nowhere.
    func focusOrNothing(_ w: AXUIElement?) {
        if let w { focus(w) } else { NSApp.activate() }
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
        item.button?.title = "\(ws.current)"
    }

    /// Left click toggles the grid under the icon, right click offers Quit.
    @objc func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
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

    @objc func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("wrkspaces: open at login: \(error)")
        }
    }

    /// App icons of each workspace, one per app, sorted by app name.
    func overview() -> [[NSImage]] {
        refresh()
        return (1...workspaceCount).map { n in
            Set(ws.windows(in: n).map(\.pid))
                .compactMap { NSRunningApplication(processIdentifier: $0) }
                .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
                .compactMap(\.icon)
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

if !AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary) {
    print("wrkspaces: waiting for Accessibility access (System Settings > Privacy & Security > Accessibility)…")
    // From a .app nobody reads this: wait for the permission rather than quit silently.
    while !AXIsProcessTrusted() { sleep(1) }
}
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)

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
