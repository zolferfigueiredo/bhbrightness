import AppKit

// ponytail: calibration knobs, tuned by eye on this panel.
let dot = 1.0 / 16 // macOS's lowest lit step (first HUD segment); sub-zero holds the backlight here
let dims = (1...16).map { pow(0.9, Double($0)) } // gamma factor per sub-zero step, darkest last

// New sub-zero depth for a plain F1/F2 press (0 = no dimming), or nil to leave the key to macOS.
func nextDepth(_ depth: Int, _ backlight: Double, up: Bool, isRepeat: Bool) -> Int? {
    if depth > 0 { return up ? depth - 1 : min(depth + 1, dims.count) }
    if up || backlight > dot + 0.004 { return nil } // 0.004 absorbs brightness readback rounding
    return isRepeat ? 0 : 1 // holding F1 stops at the first dot; sub-zero needs a fresh press
}

if CommandLine.arguments.contains("--selftest") {
    let n = dims.count
    precondition(dims == dims.sorted(by: >) && dims.first! < 1 && dims.last! > 0)
    precondition(nextDepth(0, 0.5, up: false, isRepeat: false) == nil)
    precondition(nextDepth(0, 0.125, up: false, isRepeat: false) == nil)
    precondition(nextDepth(0, dot, up: true, isRepeat: false) == nil)
    precondition(nextDepth(0, dot, up: false, isRepeat: false) == 1)
    precondition(nextDepth(0, dot, up: false, isRepeat: true) == 0)
    precondition(nextDepth(0, 0, up: false, isRepeat: false) == 1)
    precondition(nextDepth(3, dot, up: false, isRepeat: true) == 4)
    precondition(nextDepth(n, dot, up: false, isRepeat: false) == n)
    precondition(nextDepth(1, dot, up: true, isRepeat: true) == 0)
    print("selftest ok")
    exit(0)
}

typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
// Private API: the only way to set the built-in backlight to arbitrary values.
let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
let dsGet = unsafeBitCast(dlsym(ds, "DisplayServicesGetBrightness")!, to: GetFn.self)
let dsSet = unsafeBitCast(dlsym(ds, "DisplayServicesSetBrightness")!, to: SetFn.self)

var depth = 0
var ownsKey = false // whether the current press is ours, so its key-up is swallowed too
var tap: CFMachPort?
var osd: NSXPCConnection?
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

// The private XPC service behind the system volume/brightness square, called the same way as in
// deej-mac and MonitorControl. Best effort: a lost HUD never blocks a brightness change.
@objc protocol OSDUIHelperProtocol {
    func showImage(_ image: Int64, onDisplayID: UInt32, priority: UInt32, msecUntilFade: UInt32,
                   filledChiclets: UInt32, totalChiclets: UInt32, locked: Bool)
}

func showHUD(_ d: CGDirectDisplayID, filled: Int, total: Int) {
    if osd == nil {
        let c = NSXPCConnection(machServiceName: "com.apple.OSDUIHelper", options: [])
        c.remoteObjectInterface = NSXPCInterface(with: OSDUIHelperProtocol.self)
        // OSDUIHelper exits when idle; forget the connection so the next call opens a fresh one.
        c.invalidationHandler = { DispatchQueue.main.async { osd = nil } }
        c.interruptionHandler = c.invalidationHandler
        c.resume()
        osd = c
    }
    (osd?.remoteObjectProxyWithErrorHandler { _ in } as? OSDUIHelperProtocol)?
        .showImage(1, onDisplayID: d, priority: 0x1f4, msecUntilFade: 1000, // image 1 = sun
                   filledChiclets: UInt32(filled), totalChiclets: UInt32(total), locked: false)
}

func setDepth(_ n: Int, _ d: CGDirectDisplayID) {
    if n > 0 {
        _ = dsSet(d, Float(dot))
        gamma(d, dims[n - 1])
    } else if depth > 0 {
        gamma(d, 1)
    }
    depth = n
    // In sub-zero the bar restarts full and empties; at the first dot it matches macOS's own 1 of 16.
    if n > 0 { showHUD(d, filled: dims.count - n, total: dims.count) } else { showHUD(d, filled: 1, total: 16) }
}

// Returns true to swallow the event.
func handle(_ cg: CGEvent) -> Bool {
    guard let e = NSEvent(cgEvent: cg), e.type == .systemDefined,
          e.subtype.rawValue == 8 else { return false } // NX_SUBTYPE_AUX_CONTROL_BUTTONS
    let key = (e.data1 >> 16) & 0xFFFF, isDown = (e.data1 >> 8) & 0xFF == 0xA, isRepeat = e.data1 & 1 == 1
    guard key == 2 || key == 3, // NX_KEYTYPE_BRIGHTNESS_UP / _DOWN
          cg.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).isEmpty else { return false }
    if !isDown { return ownsKey }
    guard let d = builtin(), let b = backlight(d),
          let n = nextDepth(depth, b, up: key == 2, isRepeat: isRepeat) else { ownsKey = false; return false }
    ownsKey = true
    DispatchQueue.main.async { setDepth(n, d) }
    return true
}

func startTap() {
    tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                            eventsOfInterest: 1 << 14, // NX_SYSDEFINED only, so typing never waits on this tap
                            callback: { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        return handle(event) ? nil : Unmanaged.passUnretained(event)
    }, userInfo: nil)
    if let tap { CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes) }
}

item.button?.image = NSImage(systemSymbolName: "sun.min", accessibilityDescription: "Sub-zero dimming")
item.menu = NSMenu()
item.menu?.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { _ in
    if depth > 0, let d = builtin() { gamma(d, 1) }
}

// ponytail: one 1 s poll covers trust and gamma resets; move to notifications if it ever costs anything.
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    // An untrusted tap is still created, with its events silently dropped, so gate on trust.
    if tap == nil, AXIsProcessTrusted() { startTap() }
    guard depth > 0, let d = builtin() else { return }
    if let b = backlight(d), b > dot + 0.004 { depth = 0; gamma(d, 1) } // raised elsewhere: leave sub-zero
    else if abs(gammaTop(d) - dims[depth - 1]) > 0.01 { gamma(d, dims[depth - 1]) } // macOS resets gamma on wake and display changes
}

_ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
app.run()
