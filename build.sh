#!/bin/sh
set -eu
cd "$(dirname "$0")"
NAME=BiHanBrightness
VERSION=1.0.1
APP="/Applications/$NAME.app"

swiftc -O -swift-version 5 main.swift -o "$NAME"
./"$NAME" --selftest

if pkill -x "$NAME"; then sleep 1; fi
mkdir -p "$APP/Contents/MacOS"
mv "$NAME" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.bihanbrightness</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# A certificate identity (not ad-hoc) keeps the Accessibility grant across rebuilds.
codesign --force --sign "Apple Development" "$APP"

# -dev: developer-signed and not notarized, and kept apart from release.sh's DMG.
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p dist
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -format UDZO -ov "dist/$NAME-$VERSION-dev.dmg" >/dev/null
rm -rf "$STAGE"

# Launch through LaunchServices: running the bare binary makes TCC attribute it to Terminal.
open "$APP"
