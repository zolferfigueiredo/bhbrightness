#!/bin/sh
# One-time setup: xcrun notarytool store-credentials bihan --key <AuthKey.p8> --key-id <id> --issuer <issuer-id>
set -eu
cd "$(dirname "$0")"
NAME=BiHanBrightness
VERSION=${1:?usage: ./release.sh <version>}
ID="Developer ID Application: Zolfer Figueiredo (497V6MCDS8)"
APP="dist/dmg/$NAME.app"
DMG="dist/$NAME-$VERSION.dmg"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist/AppIcon.iconset
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos11 main.swift -o "dist/$NAME-$arch"
done
lipo -create "dist/$NAME-arm64" "dist/$NAME-x86_64" -output "$APP/Contents/MacOS/$NAME"
rm "dist/$NAME-arm64" "dist/$NAME-x86_64"
"$APP/Contents/MacOS/$NAME" --selftest

# icon.svg is full-bleed for the README; app icons leave a margin around the rounded square.
sed 's/viewBox="0 0 48 48"/viewBox="-6 -6 60 60"/' icon.svg > dist/icon.svg
sips -s format png -z 1024 1024 dist/icon.svg --out dist/AppIcon.iconset/icon_512x512@2x.png >/dev/null
iconutil -c icns dist/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
rm -r dist/icon.svg dist/AppIcon.iconset

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.zolfer.bihanbrightness</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "$ID" "$APP"

ln -s /Applications dist/dmg/Applications
hdiutil create -volname "$NAME" -srcfolder dist/dmg -format UDZO "$DMG"
codesign --timestamp --sign "$ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile bihan --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"
echo "Release ready: $DMG"
