#if canImport(AppKit)
import AppKit

typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
// Private API: the only way to set the built-in backlight to arbitrary values.
let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
let dsGet = unsafeBitCast(dlsym(ds, "DisplayServicesGetBrightness")!, to: GetFn.self)
let dsSet = unsafeBitCast(dlsym(ds, "DisplayServicesSetBrightness")!, to: SetFn.self)

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
#endif
