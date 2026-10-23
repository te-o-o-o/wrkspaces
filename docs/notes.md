# Notes

## Decisions

- Windows are keyed by their CGWindowID, not their AX element: Zen (Firefox based) once came back at the fallback position after a ⌃⇧N round trip, which suggests an app can hand out a new element for the same window. Getting the id takes `_AXUIElementGetWindow`, a private call (no public alternative; AeroSpace, yabai and Rectangle rely on it; no SIP change).
- The grid's drag cursors take the second private call, `CGSSetConnectionProperty(…, "SetsCursorInBackground")`: macOS only lets the active app set the cursor, and the grid must not take the focus. Cosmetic: if Apple drops it, only the hands are lost.
- The grid orders apps by the window server's stacking (`CGWindowListCopyWindowInfo`, on-screen only): parked windows stay on screen by a pixel, so they keep their rank, and within a workspace the first is the last used. No permission needed for window numbers.
- Empty workspace: wrkspaces takes the focus itself (it has no window, so keystrokes go nowhere). Finder was rejected: its windows parked elsewhere would trigger the follow-on-activation.
- Open at Login through `SMAppService.mainApp`, off by default, only offered when running as a .app.
- The icon opens the grid rather than a menu: lighter to read. Quit sits on right-click, the usual place for menu bar apps.
- Testing clicks: the status item moves with the frontmost app's menus, so read its position before clicking (`position of menu bar item 1 of menu bar 1`).
- Switcher shown 0.15 s after ⌃N if ⌃ is still held, like Cmd-Tab: `⌃` alone is too common (Ctrl-C, Ctrl-click) to trigger anything.
- Testing it with System Events: `key code … using control down` releases ⌃ at the end; use `key down control` then a bare `key code`.
- Workspaces emulated AeroSpace-style (windows parked off-screen) rather than real Spaces: no SIP, no private Spaces API, instant, survives macOS updates.
- Shortcuts `⌃1…9` / `⌃⇧1…9` reuse the native Spaces ones: nothing to learn. Physical key codes, so they work the same on AZERTY.
- Carbon `RegisterEventHotKey` for hotkeys: no extra permission, unlike a CGEvent tap.
- AX messaging timeout lowered to 0.25 s so a hung app cannot freeze a switch.

## Not handled yet

- Multiple screens (windows are parked past all screens, but workspaces are global).
- Focus change inside one app (⌘`) onto a parked window does not follow it.
- i18n of the menu.

## Verified

| OS | Status |
|---|---|
| macOS 27.0.1 (arm64) | switch, ⌃⇧N, restore on SIGTERM, switcher grid (held ⌃ shows it, quick tap does not), grid from the icon (click a tile, click outside closes, right-click Quit) verified, 1 screen, 7 apps; Cmd-Tab follow seen working by side effect; empty workspace takes focus, quit restores after ⌃⇧N races (3 scripted runs); .app builds and signs, not launched yet |

## Pitfalls

- The grid panel never becomes key: hover needs a tracking area with `.activeAlways`, added in `viewDidMoveToWindow` (`updateTrackingAreas` was never called for it).

- macOS clamps the parked position vertically (asked for y=981, got 865–889 depending on the window): only x is reliable, hence `isHidden` checks x only.
