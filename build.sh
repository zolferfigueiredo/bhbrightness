#!/bin/sh
set -eu
cd "$(dirname "$0")"
NAME=BiHanBrightness
VERSION=1.0.0
APP="/Applications/$NAME.app"

swiftc -O -swift-version 5 main.swift -o "$NAME"
./"$NAME" --selftest

if pkill -x "$NAME"; then sleep 1; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mv "$NAME" "$APP/Contents/MacOS/"
# Same icon as release.sh; the About window shows it.
T=$(mktemp -d)
mkdir "$T/AppIcon.iconset"
sed 's/viewBox="0 0 48 48"/viewBox="-6 -6 60 60"/' icon.svg > "$T/icon.svg"
sips -s format png -z 1024 1024 "$T/icon.svg" --out "$T/AppIcon.iconset/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$T/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
rm -r "$T"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.bihanbrightness</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# A certificate identity (not ad-hoc) keeps the Accessibility grant across rebuilds.
codesign --force --sign "Apple Development" "$APP"
# Launch through LaunchServices: running the bare binary makes TCC attribute it to Terminal.
open "$APP"
