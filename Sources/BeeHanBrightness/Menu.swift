#if canImport(AppKit)
import AppKit
import ServiceManagement

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

func menuItem(_ title: String, _ action: Selector?, key: String = "", symbol: String? = nil) -> NSMenuItem {
    let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
    mi.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    return mi
}
let menu = NSMenu()
// Without Accessibility access BeeHan never sees the brightness keys, so the menu leads with a way to allow it.
let accessItem = menuItem("Allow Accessibility access…", #selector(NSApplication.openAccessibilitySettings),
                          symbol: "exclamationmark.triangle")
let accessLine = NSMenuItem.separator()
let loginItem = menuItem("Launch at login", #selector(NSApplication.toggleLogin))
let dockItem = menuItem("Keep in Dock", #selector(NSApplication.toggleDock))
let checkItem = menuItem("Check for updates…", #selector(NSApplication.checkNow), symbol: "arrow.down.circle")
let every = NSMenu()
let autoItem = menuItem("Check automatically", nil)

// Fills in the menu and hangs it on the menu bar icon.
func setUpMenu() {
    for (seconds, title) in [(86400, "Daily"), (604800, "Weekly"), (0, "Never")] {
        let choice = menuItem(title, #selector(NSApplication.pickUpdateEvery))
        choice.tag = seconds
        every.addItem(choice)
    }
    autoItem.submenu = every
    autoItem.image = NSImage(size: NSSize(width: 16, height: 16)) // lines the title up with the icon rows
    for mi in [accessItem, accessLine, loginItem, dockItem, .separator(),
               menuItem("About BeeHan Brightness", #selector(NSApplication.showAbout), symbol: "info.circle"), .separator(),
               checkItem, autoItem, .separator(),
               menuItem("Quit BeeHan Brightness", #selector(NSApplication.terminate(_:)), key: "q", symbol: "xmark.square")] {
        menu.addItem(mi)
    }
    menu.autoenablesItems = false
    item.menu = menu
    // The menu is built once, so its checkmarks are refreshed as it opens.
    NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: menu, queue: .main) { _ in
        accessItem.isHidden = AXIsProcessTrusted()
        accessLine.isHidden = accessItem.isHidden
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        // Registering from anywhere else (a build folder) would point the login item at a bundle that disappears.
        loginItem.isEnabled = Bundle.main.bundlePath.hasPrefix("/Applications/")
        dockItem.state = inDock() ? .on : .off
        checkItem.isEnabled = !checking
        if let version = availableUpdate() {
            checkItem.attributedTitle = updateAvailableTitle(version)
            checkItem.image = updateAvailableIcon()
        } else {
            checkItem.attributedTitle = nil
            checkItem.title = "Check for updates…"
            checkItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        }
        for choice in every.items { choice.state = defaults.integer(forKey: "updateEvery") == choice.tag ? .on : .off }
    }
}

// Opening the app again (its Dock shortcut, Spotlight, Finder) shows the menu at the pointer.
// That also reaches it when the notch hides the menu bar icon.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        return false
    }
}
let appDelegate = AppDelegate()  // app.delegate doesn't retain it

extension NSApplication {
    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            print("launch at login: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
}
#endif
