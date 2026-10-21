#!/bin/sh
# Builds .build/wrkspaces.app: a menu bar app (no Dock icon) holding its own
# Accessibility permission, unlike `swift run` which borrows the terminal's.
set -eu
cd "$(dirname "$0")"

VERSION=0.1.1  # the one version: README badges and the release tag must match it
APP=.build/wrkspaces.app

# Universal: one download for Apple Silicon and Intel Macs.
ARCHS="--arch arm64 --arch x86_64"
swift build -c release $ARCHS
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release $ARCHS --show-bin-path)/wrkspaces" "$APP/Contents/MacOS/"
# The icon is drawn by code, like the menu bar one: no image to keep in sync.
mkdir -p "$APP/Contents/Resources"
swift appicon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>io.github.te-o-o-o.wrkspaces</string>
    <key>CFBundleName</key><string>wrkspaces</string>
    <key>CFBundleExecutable</key><string>wrkspaces</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF
# Ad-hoc signature: macOS ties the Accessibility permission to it, and every rebuild
# changes it, so the permission must be granted again after rebuilding.
codesign --force --sign - "$APP"
echo "$APP"
