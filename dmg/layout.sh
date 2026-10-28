#!/bin/bash
# Makes dmg/layout.DS_Store, the DMG window's layout that release.sh copies into every DMG: Finder lays out a test
# DMG of dist/dmg and saves it. Run it after ./release.sh build when the background or the icon spots change; it opens
# a Finder window for a moment. Icon positions must match the arrow and labels in release.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d "dist/dmg/BeeHan Brightness.app" ] || { echo "dist/dmg/BeeHan Brightness.app is missing: run ./release.sh build first." >&2; exit 1; }
# Finder finds the volume by name, so every mounted one ("BeeHan Brightness 1"...) is ejected first.
mount | { grep -i " on /Volumes/BeeHan Brightness" || true; } | sed 's|^.* on \(/Volumes/[^(]*\) (.*|\1|' |
    while IFS= read -r volume; do hdiutil detach -quiet -force "$volume"; done
WORK=$(mktemp -d /tmp/beehan-layout.XXXXXX)
MNT="/Volumes/BeeHan Brightness"
trap 'hdiutil detach -quiet -force "$MNT" 2>/dev/null || true; rm -rf "$WORK"' EXIT
ln -sfn /Applications dist/dmg/Applications
rm -f dist/dmg/.DS_Store
hdiutil create -quiet -volname "BeeHan Brightness" -srcfolder dist/dmg -format UDRW "$WORK/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$WORK/rw.dmg"
# Finder sees a new volume a moment after it mounts; asked too soon, it can't get disk "BeeHan Brightness".
for i in $(seq 31); do
    [ "$(osascript -e 'tell application "Finder" to exists disk "BeeHan Brightness"')" != true ] || break
    [ "$i" -le 30 ] || { echo "Finder didn't see the DMG's disk within 30 seconds." >&2; exit 1; }
    sleep 1
done
osascript <<'EOF'
tell application "Finder" to tell disk "BeeHan Brightness"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 800, 552}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 100
    set text size of opts to 10
    set background picture of opts to file "BeeHan Brightness.app:Contents:Resources:dmg-background.tiff"
    set position of item "BeeHan Brightness.app" to {170, 160}
    set position of item "Applications" to {430, 160}
    close
end tell
EOF
# A Finder that can't be scripted would leave this waiting for ever.
for i in $(seq 61); do
    [ ! -f "$MNT/.DS_Store" ] || break
    [ "$i" -le 60 ] || { echo "Finder didn't lay out the DMG within a minute." >&2; exit 1; }
    sleep 1
done
sync
cp "$MNT/.DS_Store" dmg/layout.DS_Store
echo "Wrote dmg/layout.DS_Store"
