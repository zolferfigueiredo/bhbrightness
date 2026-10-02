<p align="center">
  <img src="icon.svg" width="128" height="128" alt="BeeHan Brightness icon">
</p>

<h1 align="center">BeeHan Brightness</h1>

<h3 align="center">Darker than macOS allows.</h3>

<p align="center">
  16 brightness steps below the lowest one macOS gives your MacBook display.<br>
  The same brightness keys, the same kind of indicator, just further down.
</p>

<p align="center">
  <a href="https://github.com/zolferfigueiredo/bhbrightness/releases/latest"><img src="https://img.shields.io/github/v/release/zolferfigueiredo/bhbrightness" alt="Latest release"></a>
  <a href="https://www.swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6.0"></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue" alt="macOS 13 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT license"></a>
  <a href="https://github.com/zolferfigueiredo/bhbrightness/actions/workflows/ci.yml"><img src="https://github.com/zolferfigueiredo/bhbrightness/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
</p>

<p align="center">
  <a href="https://github.com/zolferfigueiredo/bhbrightness/releases/latest"><b>Download for macOS</b></a>
  &nbsp;·&nbsp;
  <a href="https://bhb.zolfer.com">Website</a>
</p>

## Install

1. [Download the DMG](https://github.com/zolferfigueiredo/bhbrightness/releases/latest), open it and drag BeeHan Brightness to Applications.
2. Open BeeHan Brightness. It's signed and notarized by Apple, so macOS only asks you to confirm the first time.
3. Allow it in System Settings > Privacy & Security > Accessibility, so it can see the brightness keys. Until you do, its menu starts with **Allow Accessibility access…**, which opens that page. It starts listening within a second, no relaunch needed.

Or install it with [Homebrew](https://brew.sh/):

```bash
brew install --cask zolferfigueiredo/app/beehan-brightness
```

You need:

- A Mac with a built-in display, such as a MacBook
- macOS 13 or later, on Apple silicon or Intel
- BeeHan Brightness in Applications, for launch at login and updates

## Features

- **16 steps below zero.** At macOS's lowest brightness, F1 keeps going, each step darker than the last. One more turns the screen off.
- **Feels like macOS.** Its indicator is drawn to the measurements of macOS's own brightness square, with a ninja for the sun.
- **Your keys, as they were.** Above the lowest step, F1 and F2 work exactly as usual. With Shift, Control, Option or Command they're left to macOS.
- **Comes back by itself.** macOS undoes the dimming after sleep and display changes, and BeeHan puts it back within a second. Quitting restores the normal screen.
- **Speaks 12 languages.** Deutsch, English, Español, Français, Italiano, Polski, Português, Русский, Українська, 中文, 日本語 and 한국어. It starts in your Mac's language, and **Language** in the menu changes it.
- **Native and tiny.** A small Swift app with no Dock icon. It can launch at login and installs updates in one click.

## How it works

- The backlight is held at the lowest lit step while the display's gamma table dims the picture further.
- macOS resets gamma after sleep and display changes, so BeeHan checks every second and puts it back.
- The BeeHan HUD is drawn to the measurements of macOS's classic brightness square, so sub-zero dimming still looks like part of the system.
- Only the built-in display is touched. External monitors are left alone.
- The backlight is set through the private DisplayServices framework, so a future macOS update could break it.
- **Check for updates…** downloads `latest.json` from bhb.zolfer.com and sends nothing about you. An update installs only if it's signed by the same developer, and only into the copy in Applications. While it installs, a window shows each step under a loading bar; **Reopen** then starts the new version. When an automatic check finds a new version, a notification says so once; clicking it offers Update Now.

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

<details>
<summary><b>Every menu item</b></summary>

- **Allow Accessibility access…**, until it's allowed: opens Privacy & Security > Accessibility.
- **Language**: the 12 languages, each named in itself.
- **Launch at login** (from the Applications folder) and **Keep in Dock**.
- **About BeeHan Brightness**: the version and the website.
- **Check for updates…**, and **Check automatically** daily, weekly (default) or never.
- **Quit BeeHan Brightness**, which puts the normal screen back.

</details>

## Build from source

```sh
./build.sh
```

It runs the tests, builds the app, signs it, installs it to `/Applications/BeeHan Brightness.app` and launches it. It also packs the app into `dist/BeeHanBrightness-<version>-dev.dmg`, which is developer-signed and not notarized, so it's for this Mac only. It needs Xcode 16 or later (Swift 6) and an Apple Development certificate, which also keeps the Accessibility permission across rebuilds.

To try a change, run `./run.sh`. It quits any running BeeHan, builds the app into `.build/` without installing or signing it, and runs it in the foreground. It starts the program inside the app directly rather than through `open`, so the Accessibility permission belongs to your terminal app; grant it there.

`./run.sh -testNotifications YES` also shows the update notification, offering the next version, to check how it reads. The installed app does the same with `open -a "BeeHan Brightness" --args -testNotifications YES` once quit.

`./release.sh` makes the notarized DMG for sharing, using the version set in `build.sh`, and publishes it as a GitHub release of the current commit, which must be pushed. `./release.sh --url` also makes the permanent url.zolfer.com download link.

A Swift package: the app is in `Sources/BeeHanBrightness`, one file per part (`Dimming`, `Display`, `KeyTap`, `HUD`, `Menu`, `Language`, `Updates`, `Dock`, `About`), the text of each language is in `Strings`, and the tests are in `Tests`. CI builds and tests every pull request on macOS, and runs the tests again on Linux, since everything that needs AppKit is behind `#if canImport(AppKit)`. Any compiler warning counts as an error. It also runs shellcheck on the scripts, and fails a pull request that changes the app without raising `VERSION` in `build.sh`.

<details>
<summary><b>Tuning</b></summary>

Two values in [Dimming.swift](Sources/BeeHanBrightness/Dimming.swift) control the feel:

- `dot` is the backlight level held during sub-zero dimming (macOS's lowest step, `1/16`).
- `dims` is the darkening per sub-zero step, `0.9^n` for 16 steps. Change the base or the count to go deeper or finer.

Run `./build.sh` again after editing.

</details>

## Uninstall

```bash
brew uninstall --cask beehan-brightness
```

Or quit from the menu bar icon and delete `/Applications/BeeHan Brightness.app`. Either way, remove it from the Accessibility list in Privacy & Security too.

## Disclaimer

Unofficial. Not affiliated with or endorsed by Apple. It relies on a private macOS framework that a future macOS update may change or remove.

## License

[MIT](LICENSE)

---

<p align="center">
  If BeeHan Brightness is useful to you, please consider giving it a ⭐<br>
  It helps other night owls find it. Thank you!
</p>

<p align="center">
  Made with ❤️ for late nights by <a href="https://zolfer.com">zolfer.com</a>
</p>
