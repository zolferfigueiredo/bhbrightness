#if canImport(AppKit)
import AppKit

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
// Built on first show.
let hud: NSWindow = {
    let window = NSWindow(contentRect: hudView.frame, styleMask: .borderless, backing: .buffered, defer: true)
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    window.ignoresMouseEvents = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.appearance = NSAppearance(named: .darkAqua) // the dark square in light mode too
    let blur = NSVisualEffectView(frame: hudView.frame)
    blur.material = .hudWindow
    blur.state = .active // the app is never active, and the default state would render the blur inactive
    blur.maskImage = NSImage(size: hudView.frame.size, flipped: false) { NSBezierPath(roundedRect: $0, xRadius: 18, yRadius: 18).fill(); return true }
    blur.addSubview(hudView)
    window.contentView = blur
    return window
}()
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
#endif
