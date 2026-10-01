<img src="icon.svg" width="128" alt="BeeHanBrightness icon">

# BeeHanBrightness

A tiny macOS menu bar app that takes your MacBook's built-in display below zero, darker than the lowest brightness macOS allows. BeeHan stays out of the way until the screen needs to go cold.

## Sub-zero dimming

macOS stops at its lowest brightness step, the first segment of its brightness indicator. Sub-zero dimming picks up from there.

- Above the lowest step, F1 and F2 (brightness down and up) work exactly as usual, with macOS's own indicator (the system HUD).
- At the lowest step, F1 enters sub-zero dimming: 16 extra steps, each darker than the last. They show on the BeeHan HUD, a brightness square with the ninja, whose bar empties as the screen darkens.
- One more F1 after the darkest sub-zero step turns the screen off, as macOS does at its lowest step. F2 turns it back on at the darkest step.
- Holding F1 goes all the way down in one hold: macOS's steps first, then straight on into sub-zero and on to off.
- F2 walks back out one step at a time. Held, it hands over to macOS at the lowest step and keeps climbing under the system HUD.
- Brightness keys pressed with Shift, Control, Option or Command are left to macOS.
- Raising the brightness any other way (Control Center, System Settings) leaves sub-zero dimming on its own.
- Quitting restores the normal screen.

## How it works

- The backlight is held at the lowest lit step while the display's gamma table dims the picture further.
- macOS resets gamma after sleep and display changes, so BeeHan checks every second and puts it back.
- The BeeHan HUD is drawn to the measurements of macOS's classic brightness square, so sub-zero dimming still looks like part of the system.
- Only the built-in display is touched. External monitors are left alone.
- The backlight is set through the private DisplayServices framework, so a future macOS update could break it.

## Requirements

- A MacBook with a built-in display
- Xcode 16 or later (Swift 6)
- An "Apple Development" signing certificate
- Accessibility permission, needed to catch the brightness keys

## Build and install

```bash
./build.sh
```

The script runs the tests (`swift test`), builds the app, signs it, installs it to `/Applications/BeeHan Brightness.app` and launches it. It also packs the app into `dist/BeeHanBrightness-<version>-dev.dmg`, which is developer-signed and not notarized, so it is for this Mac only. `release.sh` makes the notarized DMG for sharing, using the version set in `build.sh`. `release.sh --url` also makes the permanent url.zolfer.com download link.

For quick testing, `./run.sh` quits any running BeeHan, builds the app into `.build/` without installing or signing it, and runs it in the foreground. It starts the program inside the app directly rather than through `open`, so the Accessibility permission belongs to your terminal app; grant it there. `./run.sh -testNotifications YES` also shows the update notification, offering the next version, to check how it reads; the installed app does the same with `open -a "BeeHan Brightness" --args -testNotifications YES` once quit.

On first launch macOS asks for Accessibility access. Allow it in System Settings > Privacy & Security > Accessibility. BeeHan starts listening within a second, no relaunch needed. Until access is allowed, the menu starts with **Allow Accessibility access…**, which opens that page. Signing with a certificate (not ad-hoc) keeps the permission across rebuilds.

To start it at login, turn on **Launch at login** in the menu.

Click the menu bar icon for Language, Launch at login, Keep in Dock, About (version and website), Check for updates…, Check automatically (daily, weekly by default, or never) and Quit.

BeeHan speaks 12 languages: Deutsch, English, Español, Français, Italiano, Polski, Português, Русский, Українська, 中文, 日本語 and 한국어. It starts in your Mac's language (English when it speaks none of those), and **Language** in the menu changes it.

**Check for updates…** asks bhb.zolfer.com for `latest.json`, a plain download that sends nothing about you. When there is a newer version, **Update Now** downloads it, checks it is signed by you and replaces the copy in Applications, showing each step and a loading bar; **Reopen** then starts the new version. When an automatic check finds a new version, a notification says so once; clicking it offers Update Now. BeeHan needs macOS 13 or later.

## Tuning

Two values in [Dimming.swift](Sources/BeeHanBrightness/Dimming.swift) control the feel:

- `dot` is the backlight level held during sub-zero dimming (macOS's lowest step, `1/16`).
- `dims` is the darkening per sub-zero step, `0.9^n` for 16 steps. Change the base or the count to go deeper or finer.

Run `./build.sh` again after editing.

## Code

A Swift package: the app is in `Sources/BeeHanBrightness`, one file per part (`Dimming`, `Display`, `KeyTap`, `HUD`, `Menu`, `Language`, `Updates`, `Dock`, `About`), the text of each language is in `Strings`, and the tests are in `Tests`. `swift test` runs them; they also run on Linux in CI, since everything that needs AppKit is behind `#if canImport(AppKit)`. CI also runs shellcheck on the scripts, counts any compiler warning as an error, and fails a pull request that changes the app without raising `VERSION` in `build.sh`.

## Uninstall

Quit from the pixel-art icon in the menu bar, delete `/Applications/BeeHan Brightness.app` and remove it from the Accessibility list.
