<h1 align="center">wrkspaces</h1>
<p align="center">Virtual desktops for macOS. No tiling, no animation, nothing to learn.</p>
<p align="center"><sub>v0.1.0 · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#features">Features</a> · <a href="#install">Install</a> · <a href="#usage">Usage</a> · <a href="#development">Development</a> · <a href="README.fr.md">Français</a></p>

## Features

- **Instant switch**: nine workspaces, no sliding animation, no SIP to disable.
- **Shortcuts you already know**: the same ones as macOS's own Spaces.
- **Follows you**: Cmd-Tab or the Dock onto a window on another workspace takes you there.
- **Nothing lost**: quitting, Ctrl-C or a crash puts every window back on screen.
- **No config**: one menu bar item showing the current workspace.

## Install

No release yet. From source (needs the Xcode Command Line Tools):

```sh
git clone https://github.com/te-o-o-o/wrkspaces && cd wrkspaces
swift run -c release wrkspaces
```

On first launch macOS asks for Accessibility access. When run from a terminal, it is the terminal that needs it.

## Usage

| Shortcut | Action |
|---|---|
| `⌃1` … `⌃9` | go to workspace N |
| `⌃⇧1` … `⌃⇧9` | send the focused window to workspace N |

If macOS's own "Switch to Desktop N" shortcuts are on, turn them off: System Settings > Keyboard > Keyboard Shortcuts > Mission Control.

**Not yet**: one set of workspaces for all screens, no per-screen workspaces.

## Development

```sh
swift test
swift run wrkspaces
```

How it works: windows of other workspaces are parked in the bottom-right corner of the screen, like AeroSpace does. Decisions and pitfalls are in [docs/notes.md](docs/notes.md).

## License

[MIT](LICENSE)
