<img src="icon.svg" width="128" alt="BiHanBrightness icon">

# BiHanBrightness

A tiny macOS menu bar app that takes your MacBook's built-in display below zero, darker than the lowest brightness macOS allows. BiHan stays out of the way until the screen needs to go cold.

## Sub-zero dimming

macOS stops at its lowest brightness step, the first segment of the brightness HUD. Sub-zero dimming picks up from there.

- Above the lowest step, F1 and F2 (brightness down and up) work exactly as usual.
- At the lowest step, press F1 again to enter sub-zero dimming: 16 extra steps, each darker than the last, with its own HUD bar that empties as the screen darkens.
- Holding F1 stops at the lowest step. Going sub-zero takes a fresh press, so you never slide into it by accident.
- F2 walks back out one step at a time, then keeps climbing the normal brightness scale.
- Brightness keys pressed with Shift, Control, Option or Command are left to macOS.
- Raising the brightness any other way (Control Center, System Settings) leaves sub-zero dimming on its own.
- Quitting restores the normal screen.

## How it works

- The backlight is held at the lowest lit step while the display's gamma table dims the picture further.
- macOS resets gamma after sleep and display changes, so BiHan checks every second and puts it back.
- The native brightness HUD is reused, so sub-zero dimming looks like part of the system.
- Only the built-in display is touched. External monitors are left alone.
- The backlight is set through the private DisplayServices framework, so a future macOS update could break it.

## Requirements

- A MacBook with a built-in display
- Xcode command line tools (`swiftc`)
- An "Apple Development" signing certificate
- Accessibility permission, needed to catch the brightness keys

## Build and install

```bash
./build.sh
```

The script compiles `main.swift`, runs the built-in self-test, signs the app, installs it to `/Applications/BiHanBrightness.app` and launches it.

On first launch macOS asks for Accessibility access. Allow it in System Settings > Privacy & Security > Accessibility. BiHan starts listening within a second, no relaunch needed. Signing with a certificate (not ad-hoc) keeps the permission across rebuilds.

To start it at login, add it in System Settings > General > Login Items.

Click the menu bar icon for About (opens this repository), the version, and Quit.

## Tuning

Two values at the top of `main.swift` control the feel:

- `dot` is the backlight level held during sub-zero dimming (macOS's lowest step, `1/16`).
- `dims` is the darkening per sub-zero step, `0.9^n` for 16 steps. Change the base or the count to go deeper or finer.

Run `./build.sh` again after editing.

## Uninstall

Quit from the pixel-art icon in the menu bar, delete `/Applications/BiHanBrightness.app` and remove it from the Accessibility list.
