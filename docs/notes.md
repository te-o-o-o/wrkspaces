# Notes

## Decisions

- Workspaces emulated AeroSpace-style (windows parked off-screen) rather than real Spaces: no SIP, no private API, instant, survives macOS updates.
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
| macOS 27.0.1 (arm64) | switch ⌃1↔⌃2 and restore on SIGTERM verified, 1 screen, 7 apps; ⌃⇧N and Cmd-Tab follow not yet |

## Pitfalls

- macOS clamps the parked position vertically (asked for y=981, got 865–889 depending on the window): only x is reliable, hence `isHidden` checks x only.
