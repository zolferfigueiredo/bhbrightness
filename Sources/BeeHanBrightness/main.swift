#if canImport(AppKit)
import AppKit
import UserNotifications

let app = NSApplication.shared
app.delegate = appDelegate
UNUserNotificationCenter.current().delegate = appDelegate
item.button?.image = menuBarIcon()
setUpMenu()

defaults.register(defaults: ["updateEvery": 604800])
let updates = Timer(timeInterval: 3600, target: app, selector: #selector(NSApplication.autoCheck), userInfo: nil, repeats: true)
updates.tolerance = 600
RunLoop.main.add(updates, forMode: .common)
app.autoCheck()

NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
    if depth > 0, let d = builtin() { gamma(d, 1) }
}

// ponytail: one 1 s poll covers trust and gamma resets; move to notifications if it ever costs anything.
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    // An untrusted tap is still created, with its events silently dropped, so gate on trust.
    if tap == nil, AXIsProcessTrusted() { startTap() }
    guard depth > 0, let d = builtin() else { return }
    // Raised elsewhere: leave sub-zero. Uses step(): just after a held F1 crosses in, macOS's fade still reads above dot.
    let f = dims[min(depth, dims.count) - 1] // off keeps the darkest gamma
    if let b = backlight(d), step(b) > dot { depth = 0; gamma(d, 1) }
    else if abs(gammaTop(d) - f) > 0.01 { gamma(d, f) } // macOS resets gamma on wake and display changes
}

_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
DispatchQueue.main.async { app.showUpdateComplete() }  // once the app is running
if defaults.bool(forKey: "testNotifications") { Task { _ = await showUpdateNotification(nextPatch(appVersion)) } }
app.run()
#endif
