#if canImport(AppKit)
import AppKit
#else
import Foundation // Linux CI builds only the selftest
#endif

// ponytail: calibration knobs, tuned by eye on this panel.
let dot = 1.0 / 16 // macOS's lowest lit step (first HUD segment); sub-zero holds the backlight here
let dims = (1...16).map { pow(0.9, Double($0)) } // gamma factor per sub-zero step, darkest last

// Native step at or below a backlight readback; 0.004 absorbs readback rounding.
func step(_ backlight: Double) -> Double { ((backlight + 0.004) * 16).rounded(.down) / 16 }

// New sub-zero depth for a plain F1/F2 key-down or repeat (0 = no dimming), or nil when the step is macOS's.
func press(_ depth: Int, _ backlight: Double, up: Bool) -> Int? {
    if depth > 0 { return up ? depth - 1 : min(depth + 1, dims.count) }
    return up || step(backlight) > dot ? nil : 1
}

func isNewer(_ remote: String, than local: String) -> Bool {
    remote.compare(local, options: .numeric) == .orderedDescending
}

// `every` 0 means never.
func updateCheckIsDue(last: Date?, every: TimeInterval, now: Date) -> Bool {
    every > 0 && now.timeIntervalSince(last ?? .distantPast) >= every
}

if CommandLine.arguments.contains("--selftest") {
    let n = dims.count
    precondition(dims == dims.sorted(by: >) && dims.first! < 1 && dims.last! > 0)
    precondition(press(0, 0.5, up: false) == nil)
    precondition(press(0, 0.125, up: false) == nil)
    precondition(press(0, 0.1, up: false) == 1)
    precondition(press(0, dot, up: false) == 1)
    precondition(press(0, 0.0624999, up: false) == 1)
    precondition(press(0, 0, up: false) == 1)
    precondition(press(3, dot, up: false) == 4)
    precondition(press(n, dot, up: false) == n)
    precondition(press(3, dot, up: true) == 2)
    precondition(press(1, dot, up: true) == 0)
    precondition(press(0, dot, up: true) == nil)
    precondition(press(0, 0, up: true) == nil)
    precondition(press(0, 1, up: true) == nil)
    precondition(isNewer("0.1.10", than: "0.1.9") && isNewer("1.0.0", than: "0.9.9"))
    precondition(!isNewer("0.1.2", than: "0.1.2") && !isNewer("0.1.1", than: "0.1.2"))
    let now = Date()
    precondition(updateCheckIsDue(last: nil, every: 86400, now: now))
    precondition(!updateCheckIsDue(last: now.addingTimeInterval(-3600), every: 86400, now: now))
    precondition(updateCheckIsDue(last: now.addingTimeInterval(-86400), every: 86400, now: now))
    precondition(!updateCheckIsDue(last: nil, every: 0, now: now))
    print("selftest ok")
    exit(0)
}

#if canImport(AppKit)
import ServiceManagement

typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
// Private API: the only way to set the built-in backlight to arbitrary values.
let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
let dsGet = unsafeBitCast(dlsym(ds, "DisplayServicesGetBrightness")!, to: GetFn.self)
let dsSet = unsafeBitCast(dlsym(ds, "DisplayServicesSetBrightness")!, to: SetFn.self)

var depth = 0
// Per key, whether this app got the current press's key-down. Its key-up must go the same way:
// macOS stops handling brightness keys after a key-down whose key-up it never gets.
var owned = [Int: Bool]()
var tap: CFMachPort?
let app = NSApplication.shared
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

func builtin() -> CGDirectDisplayID? {
    var ids = [CGDirectDisplayID](repeating: 0, count: 8), n: UInt32 = 0
    CGGetOnlineDisplayList(8, &ids, &n)
    return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 }
}

func backlight(_ d: CGDirectDisplayID) -> Double? {
    var b: Float = 0
    return dsGet(d, &b) == 0 ? Double(b) : nil
}

// f == 1 is this display's default (identity) transfer. CGDisplayRestoreColorSyncSettings is avoided
// on purpose: Lunar has seen it zero every table, blacking out the screen.
func gamma(_ d: CGDirectDisplayID, _ f: Double) {
    let g = CGGammaValue(f)
    CGSetDisplayTransferByFormula(d, 0, g, 1, 0, g, 1, 0, g, 1)
}

func gammaTop(_ d: CGDirectDisplayID) -> Double {
    var r = [CGGammaValue](repeating: 0, count: 1024), g = r, b = r, n: UInt32 = 0
    CGGetDisplayTransferByTable(d, 1024, &r, &g, &b, &n)
    return n > 0 ? Double(r[Int(n) - 1]) : 1
}

func apply(_ n: Int, _ d: CGDirectDisplayID) {
    _ = dsSet(d, Float(dot))
    if n > 0 { gamma(d, dims[n - 1]) } else if depth > 0 { gamma(d, 1) }
    depth = n
    showHUD(d, filled: dims.count - n) // empties as it gets darker, full at depth 0
}

// Returns the event to pass on, or nil to swallow it.
func handle(_ cg: CGEvent) -> CGEvent? {
    guard let e = NSEvent(cgEvent: cg), e.type == .systemDefined,
          e.subtype.rawValue == 8 else { return cg } // NX_SUBTYPE_AUX_CONTROL_BUTTONS
    let key = (e.data1 >> 16) & 0xFFFF, isDown = (e.data1 >> 8) & 0xFF == 0xA, isRepeat = e.data1 & 1 == 1
    guard key == 2 || key == 3 else { return cg } // NX_KEYTYPE_BRIGHTNESS_UP / _DOWN
    if !isDown { return owned[key] == true ? nil : cg } // modifiers may be let go first, so this precedes their check
    guard cg.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).isEmpty,
          let d = builtin(), let b = backlight(d) else {
        if !isRepeat { owned[key] = false }
        return owned[key] == true ? nil : cg
    }
    let n = press(depth, b, up: key == 2)
    if !isRepeat { owned[key] = n != nil }
    if let n {
        DispatchQueue.main.async { apply(n, d) }
        return nil
    }
    DispatchQueue.main.async { hud.orderOut(nil) } // macOS takes this step under its own system HUD
    guard owned[key] == true else { return cg }
    // Held on past sub-zero: macOS gets a key-down in this repeat's place, then the rest of the press.
    owned[key] = false
    return NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: e.timestamp, windowNumber: 0,
                              context: nil, subtype: 8, data1: key << 16 | 0xA00, data2: -1)?.cgEvent
}

func startTap() {
    tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                            eventsOfInterest: 1 << 14, // NX_SYSDEFINED only, so typing never waits on this tap
                            callback: { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let out = handle(event) else { return nil }
        return out === event ? Unmanaged.passUnretained(event) : Unmanaged.passRetained(out) // the system releases a new event
    }, userInfo: nil)
    if let tap { CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes) }
}

// Two hand-fitted bitmaps, one pixel per cell: a half-point grid shown on a 1x screen (the external
// monitors) blends four cells into each pixel and the icon turns grey.
let logo1x = [
    "......###......",
    ".....#####.....",
    "....#######....",
    "...#########...",
    "...####.####...",
    "..####...####..",
    "..###.....###..",
    "..##.......##..",
    ".##.##...##.##.",
    ".##..##.##..##.",
    ".##....#....##.",
    "..###########..",
    "..###.#.#.###..",
    "#..#..#.#..#..#",
    "##..#.#.#.#..##",
    ".##..##.##..##.",
    "..##..#.#..##..",
    "...##..#..##...",
]
let logo2x = [
    "............##............",
    "..........######..........",
    ".........########.........",
    "........##########........",
    "........##########........",
    ".......############.......",
    ".....################.....",
    ".....################.....",
    "....########..########....",
    "....########..########....",
    "...########....########...",
    "...#######......#######...",
    "..######..........######..",
    "..#####............#####..",
    "..####..............####..",
    "..##..................##..",
    "..##..................##..",
    ".###..####......####..###.",
    ".###...####....####...###.",
    ".###....###....###....###.",
    ".###..................###.",
    ".###.##....####....##.###.",
    "..###.##..######..##.###..",
    "..###...###....###...###..",
    "...##.#..##....##..#.##...",
    "...##..#..#....#..#..##...",
    "....#...#.#....#.#...#....",
    ".#..###...#....#...###..#.",
    "##...###..#....#..###...##",
    "###...###.#....#.###...###",
    ".##....##.#....#.##....##.",
    ".###....###....###....###.",
    "..####...##....##...####..",
    "....###...##..##...###....",
    ".....###...####...###.....",
    "......##..........##......",
]
func bitmap(_ grid: [String], scale: Int) -> NSBitmapImageRep {
    let w = grid[0].count, h = grid.count
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32)!
    rep.size = NSSize(width: w / scale, height: h / scale)
    let p = rep.bitmapData!
    for (y, row) in grid.enumerated() {
        for (x, ch) in row.enumerated() {
            let i = (y * w + x) * 4
            p[i] = 0; p[i + 1] = 0; p[i + 2] = 0; p[i + 3] = ch == "#" ? 255 : 0
        }
    }
    return rep
}

let icon = NSImage(size: NSSize(width: logo1x[0].count, height: logo1x.count))
icon.addRepresentation(bitmap(logo1x, scale: 1))
icon.addRepresentation(bitmap(logo2x.map { ".." + $0 + ".." }, scale: 2)) // padded to the 1x width
icon.isTemplate = true // macOS tints it: white on a dark menu bar, black on a light one
icon.accessibilityDescription = "BeeHan Brightness"
item.button?.image = icon

// BeeHan HUD: macOS's classic brightness square (OSDUIHelper's geometry, measured at 2x), with the ninja for its sun.
final class HUDView: NSView {
    var filled = 0
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0, alpha: 0.25).setFill()
        NSRect(x: 21, y: 173, width: 10 * dims.count - 1, height: 6).fill()
        NSColor(white: 0.55, alpha: 1).setFill()
        for i in 0..<filled { NSRect(x: 21 + 10 * i, y: 173, width: 9, height: 6).fill() }
        for (y, row) in logo2x.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" { NSRect(x: 61 + 3 * x, y: 33 + 3 * y, width: 3, height: 3).fill() }
        }
    }
}
let hudView = HUDView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
let hud = NSWindow(contentRect: hudView.frame, styleMask: .borderless, backing: .buffered, defer: true)
hud.level = .screenSaver
hud.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
hud.ignoresMouseEvents = true
hud.isOpaque = false
hud.backgroundColor = .clear
hud.hasShadow = false
hud.appearance = NSAppearance(named: .darkAqua) // the dark square in light mode too
let blur = NSVisualEffectView(frame: hudView.frame)
blur.material = .hudWindow
blur.state = .active // the app is never active, and the default state would render the blur inactive
blur.maskImage = NSImage(size: hudView.frame.size, flipped: false) { NSBezierPath(roundedRect: $0, xRadius: 18, yRadius: 18).fill(); return true }
blur.addSubview(hudView)
hud.contentView = blur
var hudShown = 0 // bumped per show, so an older fade leaves a newer HUD alone

func showHUD(_ d: CGDirectDisplayID, filled: Int) {
    guard let s = NSScreen.screens.first(where: { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == d })
    else { return }
    hudShown += 1
    let shown = hudShown
    hudView.filled = filled
    hudView.needsDisplay = true
    hud.setFrameOrigin(NSPoint(x: s.frame.midX - 100, y: s.frame.minY + 140))
    hud.alphaValue = 1
    hud.orderFrontRegardless()
    for i in 1...10 { // fades by hand after 1 s: an animator() fade keeps running over a newer show
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 + 0.03 * Double(i)) {
            guard shown == hudShown else { return }
            hud.alphaValue = 1 - CGFloat(i) / 10
            if i == 10 { hud.orderOut(nil) }
        }
    }
}

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
let defaults = UserDefaults.standard
// Launch argument `-updateSite http://localhost:8020/` tests against the website's run.sh.
let site = URL(string: defaults.string(forKey: "updateSite") ?? "https://bhb.zolfer.com/")!

// The site names the DMG after the version, the same rule its deploy.sh uses.
func dmgURL(_ version: String) -> URL { site.appending(path: "BeeHanBrightness-\(version).dmg") }

// The version the site offers, or nil when it can't be reached.
func latestVersion() async -> String? {
    let request = URLRequest(url: site.appending(path: "latest.json"), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    guard let (data, response) = try? await URLSession.shared.data(for: request),
          (response as? HTTPURLResponse)?.statusCode == 200,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return json["version"] as? String
}

struct UpdateError: LocalizedError {
    let errorDescription: String?
}

// Replaces the running bundle with the one in the DMG for `version`. The caller relaunches.
// URLSession downloads carry no quarantine flag, so the new copy opens without the Gatekeeper prompt.
func install(_ version: String) async throws {
    let files = FileManager.default
    let work = try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: Bundle.main.bundleURL, create: true)
    defer { try? files.removeItem(at: work) }

    let (download, response) = try await URLSession.shared.download(from: dmgURL(version))
    let dmg = work.appending(path: "update.dmg")
    try files.moveItem(at: download, to: dmg)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError(errorDescription: "The download failed.") }

    let mount = work.appending(path: "mount")
    try files.createDirectory(at: mount, withIntermediateDirectories: true)
    try await run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path)
    let fresh = work.appending(path: "BeeHanBrightness.app")
    do {
        try await run("/usr/bin/ditto", mount.appending(path: "BeeHanBrightness.app").path, fresh.path)
    } catch {
        try? await run("/usr/bin/hdiutil", "detach", mount.path, "-force")
        throw error
    }
    try? await run("/usr/bin/hdiutil", "detach", mount.path, "-force")

    try await run("/usr/bin/codesign", "--verify", "--strict", fresh.path)
    let info = Bundle(url: fresh)?.infoDictionary
    guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
          info?["CFBundleShortVersionString"] as? String == version else {
        throw UpdateError(errorDescription: "The download isn't BeeHan Brightness \(version).")
    }
    _ = try files.replaceItemAt(Bundle.main.bundleURL, withItemAt: fresh)
}

func run(_ tool: String, _ arguments: String...) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
        process.terminationHandler = { process in
            if process.terminationStatus == 0 { done.resume() }
            else { done.resume(throwing: UpdateError(errorDescription: "\((tool as NSString).lastPathComponent) failed (\(process.terminationStatus)).")) }
        }
        do { try process.run() } catch { done.resume(throwing: error) }
    }
}

// Keep in Dock pins this copy of the app like the Dock's own menu does. There is no API for it, so this
// edits the Dock's list of pinned apps and restarts the Dock, which reads the list as it starts.
let dockPrefs = UserDefaults(suiteName: "com.apple.dock")!

func isThisApp(_ tile: Any) -> Bool {
    let data = (tile as? [String: Any])?["tile-data"] as? [String: Any]
    let url = (data?["file-data"] as? [String: Any])?["_CFURLString"] as? String
    return url.flatMap(URL.init(string:))?.resolvingSymlinksInPath().path == Bundle.main.bundleURL.resolvingSymlinksInPath().path
}

func inDock() -> Bool { (dockPrefs.array(forKey: "persistent-apps") ?? []).contains(where: isThisApp) }

func toggleDockTile() {
    var tiles = dockPrefs.array(forKey: "persistent-apps") ?? []
    if tiles.contains(where: isThisApp) {
        tiles.removeAll(where: isThisApp)
    } else {
        tiles.append(["GUID": Int.random(in: 1..<Int(Int32.max)), "tile-type": "file-tile",
                      "tile-data": ["file-data": ["_CFURLString": Bundle.main.bundleURL.absoluteString, "_CFURLStringType": 15],
                                    "file-label": Bundle.main.bundleURL.deletingPathExtension().lastPathComponent,
                                    "file-type": 41]])
    }
    dockPrefs.set(tiles, forKey: "persistent-apps")
    dockPrefs.synchronize()  // written through before the Dock restarts and reads it
    _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/killall"), arguments: ["Dock"])
}

var checking = false // an update check or install is running
var about: NSWindow?
extension NSApplication {
    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://bhb.zolfer.com/")!) }
    @objc func openAuthor() { NSWorkspace.shared.open(URL(string: "https://zolfer.com/")!) }
    @objc func showAbout() {
        if about == nil {
            let name = NSTextField(labelWithString: "BeeHan Brightness")
            name.font = .boldSystemFont(ofSize: 16)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let site = NSButton(title: "Website", target: self, action: #selector(openSite))
            site.isBordered = false
            site.contentTintColor = .linkColor
            let author = NSButton(title: "Zolfer Figueiredo", target: self, action: #selector(openAuthor))
            author.isBordered = false
            author.contentTintColor = .linkColor
            let by = NSStackView(views: [NSTextField(labelWithString: "By"), author])
            by.spacing = 3
            let text = NSStackView(views: [name, by,
                                           NSTextField(labelWithString: "Version \(version)"), site])
            text.orientation = .vertical
            text.setCustomSpacing(12, after: name)
            let logo = NSImageView(image: applicationIconImage)
            logo.widthAnchor.constraint(equalToConstant: 96).isActive = true
            logo.heightAnchor.constraint(equalToConstant: 96).isActive = true
            let row = NSStackView(views: [logo, text])
            row.spacing = 24
            row.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 24, right: 40)
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.contentView = row
            w.setContentSize(row.fittingSize)
            w.isReleasedWhenClosed = false
            w.center()
            about = w
        }
        activate(ignoringOtherApps: true) // a menu bar app is never frontmost on its own
        about?.makeKeyAndOrderFront(nil)
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

    @objc func toggleDock() {
        toggleDockTile()
    }

    @objc func pickUpdateEvery(_ sender: NSMenuItem) {
        defaults.set(sender.tag, forKey: "updateEvery")
    }

    @objc func autoCheck() {
        let every = TimeInterval(defaults.integer(forKey: "updateEvery"))
        guard updateCheckIsDue(last: defaults.object(forKey: "lastUpdateCheck") as? Date, every: every, now: Date()) else { return }
        checkForUpdates(quiet: true)
    }

    @objc func checkNow() { checkForUpdates(quiet: false) }

    // Quiet checks only speak up when there is a new version.
    func checkForUpdates(quiet: Bool) {
        guard !checking else { return }
        checking = true
        Task { @MainActor in
            defer { checking = false }
            guard let latest = await latestVersion() else {
                print("update check failed")
                if !quiet { alert("Couldn't check for updates", "Check your connection and try again.") }
                return
            }
            defaults.set(Date(), forKey: "lastUpdateCheck")
            guard isNewer(latest, than: appVersion) else {
                if !quiet { alert("You're up to date!", "BeeHan Brightness \(appVersion) is currently the newest version available.", "OK") }
                return
            }
            guard alert("BeeHan Brightness \(latest) is available", "You have \(appVersion). Update now?", "Update Now", "Later") else { return }
            do {
                guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
                    throw UpdateError(errorDescription: "BeeHan Brightness updates itself only when it runs from the Applications folder.")
                }
                try await install(latest)
                let relaunch = NSWorkspace.OpenConfiguration()
                relaunch.createsNewApplicationInstance = true
                try await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: relaunch)
                terminate(nil)
            } catch {
                print("update: \(error.localizedDescription)")
                if alert("Couldn't install the update", error.localizedDescription, "Download", "Cancel") {
                    NSWorkspace.shared.open(dmgURL(latest))
                }
            }
        }
    }

    // True when the first button was clicked.
    @discardableResult
    func alert(_ title: String, _ text: String, _ buttons: String...) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        buttons.forEach { alert.addButton(withTitle: $0) }
        activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}

func menuItem(_ title: String, _ action: Selector?, key: String = "", symbol: String? = nil) -> NSMenuItem {
    let mi = NSMenuItem(title: title, action: action, keyEquivalent: key)
    mi.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    return mi
}
let menu = NSMenu()
let loginItem = menuItem("Launch at login", #selector(NSApplication.toggleLogin))
let dockItem = menuItem("Keep in Dock", #selector(NSApplication.toggleDock))
let checkItem = menuItem("Check for updates…", #selector(NSApplication.checkNow), symbol: "arrow.down.circle")
let every = NSMenu()
for (seconds, title) in [(86400, "Daily"), (604800, "Weekly"), (0, "Never")] {
    let choice = menuItem(title, #selector(NSApplication.pickUpdateEvery))
    choice.tag = seconds
    every.addItem(choice)
}
let autoItem = menuItem("Check automatically", nil)
autoItem.submenu = every
autoItem.image = NSImage(size: NSSize(width: 16, height: 16)) // lines the title up with the icon rows
for mi in [loginItem, dockItem, .separator(),
           menuItem("About BeeHan Brightness", #selector(NSApplication.showAbout), symbol: "info.circle"), .separator(),
           checkItem, autoItem, .separator(),
           menuItem("Quit BeeHan Brightness", #selector(NSApplication.terminate(_:)), key: "q", symbol: "xmark.square")] {
    menu.addItem(mi)
}
menu.autoenablesItems = false
item.menu = menu
// The menu is built once, so its checkmarks are refreshed as it opens.
NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: menu, queue: .main) { _ in
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    // Registering from anywhere else (a build folder) would point the login item at a bundle that disappears.
    loginItem.isEnabled = Bundle.main.bundlePath.hasPrefix("/Applications/")
    dockItem.state = inDock() ? .on : .off
    checkItem.isEnabled = !checking
    for choice in every.items { choice.state = defaults.integer(forKey: "updateEvery") == choice.tag ? .on : .off }
}

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
    if let b = backlight(d), step(b) > dot { depth = 0; gamma(d, 1) }
    else if abs(gammaTop(d) - dims[depth - 1]) > 0.01 { gamma(d, dims[depth - 1]) } // macOS resets gamma on wake and display changes
}

_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
app.run()
#endif
