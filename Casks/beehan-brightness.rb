# Installs the DMG of release v<version>. CI keeps version equal to the app's, so a version bump bumps it too.
# The app updates itself, so brew upgrade leaves it alone, and Gatekeeper checks its notarization.
cask "beehan-brightness" do
  version "1.2.1"
  sha256 :no_check

  url "https://github.com/zolferfigueiredo/bhbrightness/releases/download/v#{version}/BeeHanBrightness-#{version}.dmg"
  name "BeeHan Brightness"
  desc "Dims the built-in display below its lowest brightness"
  homepage "https://bhb.zolfer.com/"

  auto_updates true
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
