#!/bin/sh
set -eu
cd "$(dirname "$0")"
NAME=BeeHanBrightness
APPNAME="BeeHan Brightness"  # the app as you see it; NAME stays the program inside it and the DMG file
VERSION=1.1.7
APP="/Applications/$APPNAME.app"

swift test
swift build -c release

if pkill -x "$NAME"; then sleep 1; fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/$NAME" "$APP/Contents/MacOS/"
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
# A certificate identity (not ad-hoc) keeps the Accessibility grant across rebuilds.
codesign --force --sign "Apple Development" "$APP"

# -dev: developer-signed and not notarized, and kept apart from release.sh's DMG.
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p dist
hdiutil create -volname "$APPNAME" -srcfolder "$STAGE" -format UDZO -ov "dist/$NAME-$VERSION-dev.dmg" >/dev/null
rm -rf "$STAGE"

# Launch through LaunchServices: running the bare binary makes TCC attribute it to Terminal.
open "$APP"
