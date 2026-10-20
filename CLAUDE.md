# wrkspaces

Virtual desktops for macOS, nothing else: no tiling, no animation, no config. macOS only, Swift, no dependencies.
This project is outside the global stack table on purpose (macOS-only app, Swift chosen with the author).

| Target | Role | Rule |
|---|---|---|
| `WrkspacesCore` | which window lives on which workspace, where hidden windows park | no AppKit, no AX: pure, unit-tested |
| `wrkspaces` | AX window moves, Carbon hotkeys, menu bar item | thin shell over the core |

## Commands

- `swift build`, `swift test`, `swift run wrkspaces`
- Only Command Line Tools here (no Xcode): tests use Swift Testing, not XCTest.

## Traps

- Never touch SIP or private Spaces APIs. Workspaces are emulated: hidden windows are parked in the bottom-right corner (macOS refuses fully off-screen windows).
- Any exit path must put parked windows back (`quit()`, SIGINT/SIGTERM); a crash is caught by `recoverStrays()` on next launch.
- `#expect` cannot call `mutating` methods: store the result first.
- `swift test` sometimes fails with "plugin for module 'TestingMacros' not found" (Command Line Tools bug, random, even with no change): just rerun.
- `#expect(cgfloat == 1512 + 2560 - 1)` fails although both are 4071: write the literal.
- From `swift run`, Accessibility permission belongs to the terminal app, not to the binary.

## Rules

- Keep `README.md` and `README.fr.md` in sync with what the app actually does, in the same change.
- Commits: one line, Conventional Commits, no body, no trailer.
