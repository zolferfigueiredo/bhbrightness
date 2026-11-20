#!/bin/sh
# Set VERSION in build.sh first. Builds dist/BeeHanBrightness-<version>.dmg, signs and notarizes it with Developer ID,
# then publishes it as a GitHub release of the current commit, which must be pushed.
# .github/workflows/release.yml runs it in two halves on every push to main, and to a beta branch (<feature>-beta):
#   ./release.sh build  the tests and the unsigned dist/dmg/BeeHan Brightness.app, on GitHub's Mac
#   ./release.sh sign   Developer ID, the DMG, notarization and the release, on the self-hosted runner on z's Mac
# With neither it does both, by hand. Both stop early when this version is already released.
# One-time setup: xcrun notarytool store-credentials beehan --key <AuthKey.p8> --key-id <id> --issuer <issuer-id>
set -eu
cd "$(dirname "$0")"
MODE=all
case "${1:-}" in build | sign) MODE=$1; shift ;; esac
NAME=BeeHanBrightness
APPNAME="BeeHan Brightness"  # the app as you see it; NAME stays the program inside it and the DMG file
VERSION=$(sed -n 's/^VERSION=//p' build.sh)
ID="Developer ID Application: Zolfer Figueiredo (497V6MCDS8)"
APP="dist/dmg/$APPNAME.app"
DMG="dist/$NAME-$VERSION.dmg"
if gh release view "v$VERSION" -R zolferfigueiredo/bhbrightness >/dev/null 2>&1; then
  echo "v$VERSION is already released."
  exit 0
fi
# A version with a "-", 1.4.0-widgets-beta.1, is a beta: a pre-release, which GitHub never calls latest, so neither the
# app's update check (unless it runs a beta) nor the website or the cask offer it. A beta branch publishes betas only.
PRERELEASE=false
case $VERSION in *-*) PRERELEASE=true ;; esac
case "${GITHUB_REF_NAME:-}" in *-beta)
  [ "$PRERELEASE" = true ] || { echo "$GITHUB_REF_NAME publishes betas only, and $VERSION isn't one."; exit 0; } ;;
esac

# The build half.
if [ "$MODE" != sign ]; then
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist/AppIcon.iconset
# A clean build in /tmp, gone when this script ends.
WORK=$(mktemp -d /tmp/beehan.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
swift test --scratch-path "$WORK"
# One universal binary for Apple silicon and Intel.
universal() { swift build -c release --arch arm64 --arch x86_64 --scratch-path "$WORK" "$@"; }
universal
cp "$(universal --show-bin-path)/$NAME" "$APP/Contents/MacOS/"

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
  <key>CFBundleName</key><string>$APPNAME</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
# The DMG window's background lives inside the app, so the DMG shows nothing but the app and Applications.
swift Icon/make-dmg-background.swift "$WORK/bg"
tiffutil -cathidpicheck "$WORK/bg/background.png" "$WORK/bg/background@2x.png" -out "$APP/Contents/Resources/dmg-background.tiff"
fi

# The sign half.
[ "$MODE" != build ] || exit 0
[ -d "$APP" ] || { echo "$APP is missing: run ./release.sh build first." >&2; exit 1; }
# Notarization requires the hardened runtime and a secure timestamp.
codesign --force --options runtime --timestamp --sign "$ID" "$APP"
ln -sfn /Applications dist/dmg/Applications

# The window's layout (background, icon spots) as Finder saved it, so no Finder window opens while a release builds.
# dmg/layout.sh makes it again when the background or the icon spots change.
cp dmg/layout.DS_Store dist/dmg/.DS_Store
hdiutil create -quiet -volname "$APPNAME" -srcfolder dist/dmg -format UDZO "$DMG"
codesign --timestamp --sign "$ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile beehan --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"
echo "Release ready: $DMG"
[ "${1:-}" != --url ] || {
  loc=$(curl -fsS -o /dev/null -w '%{redirect_url}' --data-urlencode "url=https://bhb.zolfer.com/$NAME-$VERSION.dmg" https://url.zolfer.com/dmg)
  echo "Download link: https://url.zolfer.com/${loc##*c=}"
}
# The apps learn the newest version from releases/latest/download/latest.json, the same file the website serves.
printf '{"version": "%s"}\n' "$VERSION" > dist/latest.json
gh release create "v$VERSION" "$DMG" dist/latest.json -R zolferfigueiredo/bhbrightness --target "$(git rev-parse HEAD)" --title "$APPNAME $VERSION" --generate-notes --prerelease="$PRERELEASE"
