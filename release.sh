#!/bin/sh
# One-time setup: xcrun notarytool store-credentials bihan --apple-id <apple-id> --team-id 497V6MCDS8
set -eu
cd "$(dirname "$0")"
NAME=BiHanBrightness
VERSION=${1:?usage: ./release.sh <version>}
APP="dist/$NAME.app"
ZIP="dist/$NAME-$VERSION.zip"

rm -rf dist
mkdir -p "$APP/Contents/MacOS"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos11 main.swift -o "dist/$NAME-$arch"
done
lipo -create "dist/$NAME-arm64" "dist/$NAME-x86_64" -output "$APP/Contents/MacOS/$NAME"
rm "dist/$NAME-arm64" "dist/$NAME-x86_64"
"$APP/Contents/MacOS/$NAME" --selftest

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.zolfer.bihanbrightness</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "Developer ID Application: Zolfer Figueiredo (497V6MCDS8)" "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile bihan --wait
# Stapling lets Gatekeeper pass the app offline; the zip must be rebuilt to carry the ticket.
xcrun stapler staple "$APP"
rm "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute -vv "$APP"
echo "Release ready: $ZIP"
