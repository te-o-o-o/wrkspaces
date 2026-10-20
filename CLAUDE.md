# wrkspaces

Virtual desktops for macOS, nothing else: no tiling, no animation, no config. macOS only, Swift, no dependencies.
This project is outside the global stack table on purpose (macOS-only app, Swift chosen with the author).

| Target | Role | Rule |
|---|---|---|
| `WrkspacesCore` | which window lives on which workspace, where hidden windows park | no AppKit, no AX: pure, unit-tested |
| `wrkspaces` | AX window moves, Carbon hotkeys, menu bar item | thin shell over the core |

## Commands

- `swift build`, `swift test`, `swift run wrkspaces`
- `./bundle.sh`: universal release build packed as `.build/wrkspaces.app` (ad-hoc signed, `LSUIElement`); its `VERSION` is the one version
- Release: bump `VERSION` in `bundle.sh` and the README badges → date the CHANGELOG section → `chore: release X.Y.Z` → `git tag vX.Y.Z && git push --tags`; `release.yml` checks the tag against `VERSION`, tests, packs the app as a `.dmg` (with an Applications link) and a `.zip`, and publishes the GitHub release
- Only Command Line Tools here (no Xcode): tests use Swift Testing, not XCTest.

## Traps

- Never touch SIP or private Spaces APIs. Workspaces are emulated: hidden windows are parked in the bottom-right corner (macOS refuses fully off-screen windows).
- Track windows by `windowID` (CGWindowID), never by `AXUIElement`: an app may hand out a new element for the same window. Elements only live in `elements`, refreshed by `refresh()`.
- Any exit path must put parked windows back (`quit()`, SIGINT/SIGTERM); a crash is caught by `recoverStrays()` on next launch.
- `#expect` cannot call `mutating` methods: store the result first.
- `swift test` sometimes fails with "plugin for module 'TestingMacros' not found" (Command Line Tools bug, random, even with no change): just rerun.
- `#expect(cgfloat == 1512 + 2560 - 1)` fails although both are 4071: write the literal.
- From `swift run`, Accessibility permission belongs to the terminal app, not to the binary.
- Each `./bundle.sh` changes the ad-hoc signature: the Accessibility grant no longer matches, reset it with `tccutil reset Accessibility io.github.te-o-o-o.wrkspaces`.
- `NSWorkspace.frontmostApplication` is refreshed by our run loop, so it lags right after an app switch: ask AX (`kAXFocusedApplicationAttribute`) instead. That system-wide query can fail with `kAXErrorCannotComplete` (seen with Obsidian in front): keep the NSWorkspace fallback.
- `NSApp.activate()` does work for this accessory app, but System Events' `frontmost` never reports it: check with `lsappinfo front`.

## Rules

- Keep `README.md` and `README.fr.md` in sync with what the app actually does, in the same change.
- Commits: one line, Conventional Commits, no body, no trailer.
