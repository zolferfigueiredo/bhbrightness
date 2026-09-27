#!/bin/sh
set -eu
cd "$(dirname "$0")"
NAME=BiHanBrightness
APP="/Applications/$NAME.app"

swiftc -O -swift-version 5 main.swift -o "$NAME"
./"$NAME" --selftest

pkill -x "$NAME" && sleep 1 || true
mkdir -p "$APP/Contents/MacOS"
mv "$NAME" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.bihanbrightness</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# A certificate identity (not ad-hoc) keeps the Accessibility grant across rebuilds.
codesign --force --sign "Apple Development" "$APP"
# Launch through LaunchServices: running the bare binary makes TCC attribute it to Terminal.
open "$APP"
