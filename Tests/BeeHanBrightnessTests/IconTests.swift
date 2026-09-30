#if canImport(AppKit)
import AppKit
import Testing
@testable import BeeHanBrightness

// Drawn at 1x and 2x, the icon is its grid pixel for pixel, black on a light menu bar and white on a dark one.
@Test(arguments: [(logo1x, 1), (logo2x.map { ".." + $0 + ".." }, 2)])
func menuBarIconIsTheGridInTheMenuBarsColor(grid: [String], scale: Int) {
    let icon = menuBarIcon()
    #expect(!icon.isTemplate)
    for (appearance, white) in [(NSAppearance.Name.aqua, false), (.darkAqua, true)] {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: grid[0].count, pixelsHigh: grid.count, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = icon.size
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance { icon.draw(at: .zero, from: .zero, operation: .copy, fraction: 1) }
        NSGraphicsContext.current = nil
        for (y, row) in grid.enumerated() {
            for (x, ch) in row.enumerated() {
                let pixel = rep.colorAt(x: x, y: y)!
                #expect(ch == "#" ? pixel.alphaComponent > 0.8 : pixel.alphaComponent == 0, "\(appearance.rawValue) \(scale)x (\(x), \(y))")
                if ch == "#" { #expect((pixel.redComponent > 0.5) == white) }
            }
        }
    }
}
#endif
