#!/bin/sh
set -eu
cd "$(dirname "$0")"
NAME=BeeHanBrightness
APPNAME="BeeHan Brightness"  # the app as you see it; NAME stays the program inside it and the DMG file
VERSION=$(sed -n 's/^VERSION=//p' build.sh)
# A bundle, not a bare binary, so the Dock and About show the icon and version.
APP=".build/$APPNAME.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift build
cp "$(swift build --show-bin-path)/$NAME" "$APP/Contents/MacOS/"
# Same icon as build.sh.
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
  <key>CFBundleIdentifier</key><string>local.beehanbrightness</string>
  <key>CFBundleName</key><string>$APPNAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# Two instances would fight over gamma and the brightness keys.
pkill -x "$NAME" || true
# Run the binary itself, not through open: TCC then attributes Accessibility to the terminal, so grant it there.
exec "$APP/Contents/MacOS/$NAME"
