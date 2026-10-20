<h1 align="center">wrkspaces</h1>
<p align="center">Virtual desktops for macOS. No tiling, no animation, nothing to learn.</p>
<p align="center"><sub>v0.1.0 · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#features">Features</a> · <a href="#install">Install</a> · <a href="#usage">Usage</a> · <a href="#development">Development</a> · <a href="README.fr.md">Français</a></p>

<p align="center">
  <img src="docs/menubar.jpg" width="560" alt="The wrkspaces icon in the macOS menu bar, its grid open below: nine workspaces with the icons of their apps and the icon picker">
</p>

## Features

- **Instant switch**: nine workspaces, no sliding animation, no SIP to disable.
- **Shortcuts you already know**: the same ones as macOS's own Spaces.
- **Follows you**: Cmd-Tab or the Dock onto a window on another workspace takes you there.
- **Nothing lost**: quitting, Ctrl-C or a crash puts every window back on screen.
- **No config**: one menu bar item with the current workspace number and a little icon: a window with eyes, a blob, a flower whose highlighted petal is the workspace, or a ring. Pick it under the grid the icon opens.
- **See where everything is**: click the icon for a grid of the nine workspaces with their apps, click one to go there. Keep `⌃` held after `⌃N` and the same grid shows up, like Cmd-Tab. A foldable list under the grid recalls every shortcut. Right-click the icon to quit.

## Install

No release yet. From source (needs the Xcode Command Line Tools):

```sh
git clone https://github.com/te-o-o-o/wrkspaces && cd wrkspaces
./bundle.sh
cp -R .build/wrkspaces.app /Applications/
open /Applications/wrkspaces.app
```

On first launch macOS asks for Accessibility access: grant it and the app starts on its own. Right-click the icon and pick **Open at Login** to start it with your session.

After a rebuild, macOS no longer recognises the app: remove it from the Accessibility list (or run `tccutil reset Accessibility io.github.te-o-o-o.wrkspaces`) and grant it again.

## Usage

| Shortcut | Action |
|---|---|
| `⌃1` … `⌃9` | go to workspace N |
| `⌃⇧1` … `⌃⇧9` | send the focused window to workspace N |

<p align="center"><img src="docs/hold.jpg" width="560" alt="The grid shown while ⌃ is held after ⌃2: workspace 2 highlighted, each workspace with the icons of its apps"></p>

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
