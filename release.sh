#!/bin/sh
# One-time setup: xcrun notarytool store-credentials beehan --key <AuthKey.p8> --key-id <id> --issuer <issuer-id>
set -eu
cd "$(dirname "$0")"
NAME=BeeHanBrightness
VERSION=${1:-$(sed -n 's/^VERSION=//p' build.sh)}
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
  <key>CFBundleIdentifier</key><string>com.zolfer.beehanbrightness</string>
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
# The DMG window's background lives inside the app, so the DMG shows nothing but the app and Applications.
# Finder draws file names in black over a background picture, even in dark mode. They vanish on
# pure black, so the faded icon must not reach them, and the picture carries the visible labels.
# .AppleSystemUIFont is the only font name sips maps to SF.
cat > dist/background.svg <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="440">
<rect width="600" height="440"/>
<g opacity=".06">$(sed -e 's/<rect[^>]*>//' -e 's/width="128" height="128"/x="234" y="22" width="456" height="456"/' icon.svg)</g>
<g fill="none" stroke="#86868b" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
<path d="M236 166C266 124 330 120 362 152"/><path d="M349 151.5h13.5v-13.5"/>
</g>
<g font-family=".AppleSystemUIFont" font-size="16" fill="#f5f5f7" fill-opacity=".85" text-anchor="middle">
<text x="170" y="250">$NAME.app</text><text x="430" y="250">Applications</text>
</g>
</svg>
EOF
for s in 1 2; do sips -s format png -z $((440 * s)) $((600 * s)) dist/background.svg --out "dist/bg$s.png" >/dev/null; done
tiffutil -cathidpicheck dist/bg1.png dist/bg2.png -out "$APP/Contents/Resources/dmg-background.tiff"
rm dist/background.svg dist/bg1.png dist/bg2.png

# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "$ID" "$APP"
ln -s /Applications dist/dmg/Applications

# Finder's window layout (bounds, icon spots at {170,160} and {430,160}, background path), saved once
# from a DMG Finder laid out, so the build never opens Finder. The icon spots must match the picture.
cp dmg.DS_Store dist/dmg/.DS_Store
hdiutil create -volname "$NAME" -srcfolder dist/dmg -format UDZO "$DMG"
codesign --timestamp --sign "$ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile beehan --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"
echo "Release ready: $DMG"
