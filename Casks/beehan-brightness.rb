# Always the latest GitHub release: release.sh uploads a copy of each DMG as BeeHanBrightness.dmg, so this
# file never changes with a version. The app updates itself, and Gatekeeper checks its notarization.
cask "beehan-brightness" do
  version :latest
  sha256 :no_check

  url "https://github.com/zolferfigueiredo/bhbrightness/releases/latest/download/BeeHanBrightness.dmg",
      verified: "github.com/zolferfigueiredo/bhbrightness/"
  name "BeeHan Brightness"
  desc "Dims the built-in display below its lowest brightness"
  homepage "https://bhb.zolfer.com/"

  depends_on macos: :ventura

  app "BeeHan Brightness.app"

  uninstall quit: "com.zolfer.beehanbrightness"

  zap trash: [
    "~/Library/Caches/com.zolfer.beehanbrightness",
    "~/Library/HTTPStorages/com.zolfer.beehanbrightness",
    "~/Library/Preferences/com.zolfer.beehanbrightness.plist",
  ]

  caveats <<~EOS
    BeeHan needs Accessibility access to see the brightness keys. Allow it in
    System Settings > Privacy & Security > Accessibility; its menu leads there until you do.
  EOS
end
