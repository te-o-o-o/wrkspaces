# Changelog

## Unreleased

### Added

- Drag an app in the grid onto another workspace to send its windows there, also in the grid shown while `⌃` is held. Hovering highlights tiles and apps, and the cursor turns into a hand.

### Changed

- The grid lists each workspace's apps from the last used, and switching brings back the last used window.

## 0.1.5 (2026-10-23)

### Fixed

- Picking a window on another workspace with AltTab, Cmd-Tab or the Dock now brings that window forward, not the last one used there.

## 0.1.4 (2026-10-23)

### Added

- Without Accessibility access, the menu bar icon shows `!` and a menu to open the right settings or relaunch.

### Fixed

- Windows of menu bar apps, like Stats' Bluetooth window, now belong to a workspace and show in the grid.

## 0.1.3 (2026-10-22)

### Added

- The numeric keypad digits work too, with `⌃` and `⌃⇧`.

## 0.1.2 (2026-10-21)

### Changed

- The `.dmg` download is less than half its previous size.

## 0.1.1 (2026-10-21)

### Added

- An app icon: the menu bar's little window, in white on teal.

## 0.1.0 (2026-10-20)

### Added

- Nine virtual desktops, switched with `⌃1` … `⌃9`, without any animation and without touching SIP.
- `⌃⇧1` … `⌃⇧9` sends the focused window to another workspace.
- Cmd-Tab and the Dock take you to the workspace of the window you pick.
- Menu bar icon with the current workspace; a click opens a grid of the nine workspaces with their apps.
- Keeping `⌃` held after `⌃N` shows the same grid, like Cmd-Tab.
- Four icons to choose from under the grid: window, blob, flower and ring.
- Foldable list of shortcuts under the grid.
- Open at login from the icon's right-click menu.
- Windows come back on screen when the app quits, is stopped with Ctrl-C or crashes.
