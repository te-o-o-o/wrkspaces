import AppKit
import Carbon.HIToolbox
import WrkspacesCore

final class App: NSObject, NSApplicationDelegate {
    var ws = Workspaces<AXUIElement>()
    var saved: [AXUIElement: CGPoint] = [:]  // real position of each hidden window
    var lastFocused: [Int: AXUIElement] = [:]
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_: Notification) {
        recoverStrays()
        ws.sync(allWindows())
        buildMenu()
        registerHotKeys { [unowned self] id in
            id > 100 ? moveFocused(to: Int(id) - 100) : switchTo(Int(id))
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
        for n in 1...workspaceCount {
            let i = NSMenuItem(title: "\(n)", action: #selector(pick(_:)), keyEquivalent: "")
            i.target = self
            i.tag = n
            menu.addItem(i)
        }
        menu.addItem(.separator())
        let q = NSMenuItem(title: "Quit wrkspaces", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        menu.addItem(q)
        item.menu = menu
        updateMenu()
    }

    @objc func pick(_ sender: NSMenuItem) { switchTo(sender.tag) }

    func updateMenu() {
        item.button?.title = "\(ws.current)"
        item.menu?.items.forEach { $0.state = $0.tag == ws.current ? .on : .off }
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
