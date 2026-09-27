#if canImport(AppKit)
import AppKit
#else
import Foundation // Linux CI builds only the selftest
#endif

// ponytail: calibration knobs, tuned by eye on this panel.
let dot = 1.0 / 16 // macOS's lowest lit step (first HUD segment); sub-zero holds the backlight here
let dims = (1...16).map { pow(0.9, Double($0)) } // gamma factor per sub-zero step, darkest last

// New (depth, backlight) for a plain F1/F2 press (depth 0 = no dimming), or nil when the press is
// macOS's. held = a repeat of a press this app already owns.
func press(_ depth: Int, _ backlight: Double, up: Bool, held: Bool) -> (depth: Int, backlight: Double)? {
    let step = ((backlight + 0.004) * 16).rounded(.down) / 16 // native step at or below; 0.004 absorbs readback rounding
    if depth > 0 { return (up ? depth - 1 : min(depth + 1, dims.count), dot) }
    if up { return held || step <= dot ? (0, min(1, step + 1.0 / 16)) : nil }
    return held || step > dot ? nil : (1, dot) // sub-zero needs a fresh F1 press at the first dot
}

if CommandLine.arguments.contains("--selftest") {
    func check(_ r: (depth: Int, backlight: Double)?, _ want: (Int, Double)?) {
        precondition(r?.depth == want?.0 && r?.backlight == want?.1)
    }
    let n = dims.count
    precondition(dims == dims.sorted(by: >) && dims.first! < 1 && dims.last! > 0)
    check(press(0, 0.5, up: false, held: false), nil)
    check(press(0, 0.125, up: false, held: false), nil)
    check(press(0, dot, up: false, held: false), (1, dot))
    check(press(0, 0.0624999, up: false, held: false), (1, dot))
    check(press(0, 0, up: false, held: false), (1, dot))
    check(press(0, dot, up: false, held: true), nil)
    check(press(3, dot, up: false, held: true), (4, dot))
    check(press(n, dot, up: false, held: true), (n, dot))
    check(press(3, dot, up: true, held: false), (2, dot))
    check(press(1, dot, up: true, held: true), (0, dot))
    check(press(0, dot, up: true, held: false), (0, 0.125))
    check(press(0, 0.0624999, up: true, held: false), (0, 0.125))
    check(press(0, 0.125, up: true, held: false), nil)
    check(press(0, 0.125, up: true, held: true), (0, 0.1875))
    check(press(0, 1, up: true, held: true), (0, 1))
    print("selftest ok")
    exit(0)
}

#if canImport(AppKit)
typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
// Private API: the only way to set the built-in backlight to arbitrary values.
let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
let dsGet = unsafeBitCast(dlsym(ds, "DisplayServicesGetBrightness")!, to: GetFn.self)
let dsSet = unsafeBitCast(dlsym(ds, "DisplayServicesSetBrightness")!, to: SetFn.self)

var depth = 0
// Whether this app owns the current press. Its repeats and key-up must go wherever its key-down went:
// macOS stops handling brightness keys after a key-down with no key-up, or a key-up with no key-down.
var owned = false
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

func apply(_ n: Int, _ level: Double, _ d: CGDirectDisplayID) {
    _ = dsSet(d, Float(level))
    if n > 0 { gamma(d, dims[n - 1]) } else if depth > 0 { gamma(d, 1) }
    depth = n
    // Sub-zero has its own bar that empties as it gets darker; above it, macOS's 16-segment bar.
    if n > 0 { showHUD(d, filled: dims.count - n, total: dims.count) }
    else { showHUD(d, filled: Int((level * 16).rounded()), total: 16) }
}

// Returns true to swallow the event.
func handle(_ cg: CGEvent) -> Bool {
    guard let e = NSEvent(cgEvent: cg), e.type == .systemDefined,
          e.subtype.rawValue == 8 else { return false } // NX_SUBTYPE_AUX_CONTROL_BUTTONS
    let key = (e.data1 >> 16) & 0xFFFF, isDown = (e.data1 >> 8) & 0xFF == 0xA, isRepeat = e.data1 & 1 == 1
    guard key == 2 || key == 3, // NX_KEYTYPE_BRIGHTNESS_UP / _DOWN
          cg.flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).isEmpty else { return false }
    if !isDown { return owned }
    guard let d = builtin(), let b = backlight(d) else {
        if !isRepeat { owned = false }
        return owned
    }
    let r = press(depth, b, up: key == 2, held: isRepeat && owned)
    if !isRepeat { owned = r != nil }
    if owned, let r { DispatchQueue.main.async { apply(r.depth, r.backlight, d) } }
    // A held F1 owned by macOS stops at the first dot: only its repeats are dropped, never its key-up.
    return owned || (isRepeat && key == 3 && b <= dot + 0.004)
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
icon.accessibilityDescription = "BiHan Brightness"
item.button?.image = icon
extension NSApplication {
    @objc func openRepo() { NSWorkspace.shared.open(URL(string: "https://github.com/zolferfigueiredo/bihan-mac-brightness")!) }
}

item.menu = NSMenu()
item.menu?.addItem(withTitle: "About BiHanBrightness", action: #selector(NSApplication.openRepo), keyEquivalent: "")
if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
    item.menu?.addItem(withTitle: "Version \(v)", action: nil, keyEquivalent: "") // no action: shown greyed out
}
item.menu?.addItem(.separator())
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
#endif
