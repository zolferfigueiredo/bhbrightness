#if canImport(AppKit)
import AppKit

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

// The menu bar icon, from the two bitmaps above.
func menuBarIcon() -> NSImage {
    let icon = NSImage(size: NSSize(width: logo1x[0].count, height: logo1x.count))
    icon.addRepresentation(bitmap(logo1x, scale: 1))
    icon.addRepresentation(bitmap(logo2x.map { ".." + $0 + ".." }, scale: 2)) // padded to the 1x width
    icon.isTemplate = true // macOS tints it: white on a dark menu bar, black on a light one
    icon.accessibilityDescription = "BeeHan Brightness"
    return icon
}
#endif
