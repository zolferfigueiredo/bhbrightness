#if canImport(AppKit)
import AppKit

var depth = 0
// Per key, whether this app got the current press's key-down. Its key-up must go the same way:
// macOS stops handling brightness keys after a key-down whose key-up it never gets.
var owned = [Int: Bool]()
var tap: CFMachPort?

func apply(_ n: Int, _ d: CGDirectDisplayID) {
    _ = dsSet(d, n == off ? 0 : Float(dot))
    if n > 0 { gamma(d, dims[min(n, dims.count) - 1]) } else if depth > 0 { gamma(d, 1) }
    depth = n
    showHUD(d, filled: max(dims.count - n, 0)) // empties as it gets darker, full at depth 0
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
#endif
