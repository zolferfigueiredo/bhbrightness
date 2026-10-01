import Foundation

// ponytail: calibration knobs, tuned by eye on this panel.
let dot = 1.0 / 16 // macOS's lowest lit step (first HUD segment); sub-zero holds the backlight here
let dims = (1...16).map { pow(0.9, Double($0)) } // gamma factor per sub-zero step, darkest last
let off = dims.count + 1 // one F1 past the darkest step turns the backlight off, as macOS does at its lowest step

// Native step at or below a backlight readback; 0.004 absorbs readback rounding.
func step(_ backlight: Double) -> Double { ((backlight + 0.004) * 16).rounded(.down) / 16 }

// New sub-zero depth for a plain F1/F2 key-down or repeat (0 = no dimming), or nil when the step is macOS's.
func press(_ depth: Int, _ backlight: Double, up: Bool) -> Int? {
    if depth > 0 { return up ? depth - 1 : min(depth + 1, off) }
    return up || step(backlight) > dot ? nil : 1
}
