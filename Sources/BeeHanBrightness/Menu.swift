#if canImport(AppKit)
import AppKit
import ServiceManagement

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

// `title` is the string's key, kept as the identifier so the item can be named again in another language.
func menuItem(_ title: String, _ action: Selector?, key: String = "", symbol: String? = nil) -> NSMenuItem {
    let mi = NSMenuItem(title: tr(title), action: action, keyEquivalent: key)
    mi.identifier = NSUserInterfaceItemIdentifier(title)
    mi.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    return mi
}
let menu = NSMenu()
// Without Accessibility access BeeHan never sees the brightness keys, so the menu leads with a way to allow it.
let accessItem = menuItem("access", #selector(NSApplication.openAccessibilitySettings),
                          symbol: "exclamationmark.triangle")
let accessLine = NSMenuItem.separator()
// The globe is the website's language picker.
let languageItem = menuItem("language", nil, symbol: "globe")
let languages = NSMenu()
let loginItem = menuItem("login", #selector(NSApplication.toggleLogin))
let dockItem = menuItem("dock", #selector(NSApplication.toggleDock))
let checkItem = menuItem("check", #selector(NSApplication.checkNow), symbol: "arrow.down.circle")
let every = NSMenu()
let autoItem = menuItem("auto", nil)

// Fills in the menu and hangs it on the menu bar icon.
func setUpMenu() {
    // Each language is named in itself, so it can always be found.
    for language in Language.allCases {
        let choice = NSMenuItem(title: "\(language.flag) \(language.name)", action: #selector(NSApplication.pickLanguage), keyEquivalent: "")
        choice.representedObject = language.rawValue
        languages.addItem(choice)
    }
    languageItem.submenu = languages
    for (seconds, title) in [(86400, "daily"), (604800, "weekly"), (0, "never")] {
        let choice = menuItem(title, #selector(NSApplication.pickUpdateEvery))
        choice.tag = seconds
        every.addItem(choice)
    }
    autoItem.submenu = every
    autoItem.image = NSImage(size: NSSize(width: 16, height: 16)) // lines the title up with the icon rows
    for mi in [accessItem, accessLine, languageItem, .separator(), loginItem, dockItem, .separator(),
               menuItem("about", #selector(NSApplication.showAbout), symbol: "info.circle"), .separator(),
               checkItem, autoItem, .separator(),
               menuItem("quit", #selector(NSApplication.terminate(_:)), key: "q", symbol: "xmark.square")] {
        menu.addItem(mi)
    }
    menu.autoenablesItems = false
    item.menu = menu
    // The menu is built once, so its titles (the language may have changed) and checkmarks are refreshed as it opens.
    NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: menu, queue: .main) { _ in
        for mi in menu.items + every.items { if let key = mi.identifier?.rawValue { mi.title = tr(key) } }
        for choice in languages.items { choice.state = choice.representedObject as? String == Language.current.rawValue ? .on : .off }
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

    @objc func pickLanguage(_ sender: NSMenuItem) {
        defaults.set(sender.representedObject, forKey: "language")
        about?.close()  // it was built in the old language
        about = nil
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
