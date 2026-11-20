#if canImport(AppKit)
import AppKit

var about: NSWindow?
extension NSApplication {
    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://bhb.zolfer.com/")!) }
    @objc func openAuthor() { NSWorkspace.shared.open(URL(string: "https://zolfer.com/")!) }
    @objc func openCoffee() { NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/zolfer")!) }
    // A beta found while the switch was on isn't offered once it is off.
    @objc func pickCheckBetas(_ sender: NSSwitch) {
        defaults.set(sender.state == .on, forKey: "checkBetas")
        defaults.removeObject(forKey: "availableVersion")
    }
    @objc func showAbout() {
        if about == nil { about = aboutWindow() }
        activate(ignoringOtherApps: true) // a menu bar app is never frontmost on its own
        about?.makeKeyAndOrderFront(nil)
    }
}

// `version` is a parameter so a test can show the About of a beta.
@MainActor func aboutWindow(version number: String = appVersion) -> NSWindow {
    let app = NSApp!
    let logo = NSImageView(image: app.applicationIconImage)
    logo.widthAnchor.constraint(equalToConstant: 96).isActive = true
    logo.heightAnchor.constraint(equalToConstant: 96).isActive = true
    let name = NSTextField(labelWithString: "BeeHan Brightness")
    name.font = .boldSystemFont(ofSize: 16)
    let author = NSButton(title: "Zolfer Figueiredo", target: app, action: #selector(NSApplication.openAuthor))
    author.isBordered = false
    author.contentTintColor = .linkColor
    let by = NSStackView(views: [NSTextField(labelWithString: tr("by")), author])
    by.spacing = 3
    for case let view as NSControl in by.views { view.font = .systemFont(ofSize: NSFont.smallSystemFontSize) }
    let version = NSTextField(labelWithString: tr("version", ["version": number]))
    let check = NSButton(title: tr("check"), target: app, action: #selector(NSApplication.checkNow))
    let line = NSBox()
    line.boxType = .separator
    let site = NSButton(title: tr("website"), target: app, action: #selector(NSApplication.openSite))
    site.isBordered = false
    site.contentTintColor = .linkColor
    let liked = NSTextField(labelWithString: tr("liked"))
    let coffee = NSButton(title: tr("coffee"), target: app, action: #selector(NSApplication.openCoffee))
    var views: [NSView] = [logo, name, by, version]
    // Only a beta has the switch; it is on until turned off.
    var betas: NSStackView?
    if isBeta(number) {
        let toggle = NSSwitch()
        toggle.controlSize = .mini
        toggle.state = (defaults.object(forKey: "checkBetas") as? Bool ?? true) ? .on : .off
        toggle.target = app
        toggle.action = #selector(NSApplication.pickCheckBetas)
        let label = NSTextField(labelWithString: tr("check_betas"))
        let row = NSStackView(views: [label, toggle])
        row.spacing = 6
        betas = row
        views.append(row)
    }
    views += [check, line, site, liked, coffee]
    let page = NSStackView(views: views)
    page.orientation = .vertical
    page.spacing = 4
    page.setCustomSpacing(12, after: logo)
    for view in [name, by] { page.setCustomSpacing(10, after: view) }
    page.setCustomSpacing(betas == nil ? 16 : 10, after: version)
    if let betas { page.setCustomSpacing(16, after: betas) }
    for view in [check, line] { page.setCustomSpacing(16, after: view) }
    page.setCustomSpacing(10, after: site)
    page.setCustomSpacing(8, after: liked)
    page.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
    page.widthAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
    line.widthAnchor.constraint(equalTo: page.widthAnchor, constant: -48).isActive = true
    let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
    w.contentView = page
    w.setContentSize(page.fittingSize)
    w.isReleasedWhenClosed = false
    w.center()
    return w
}
#endif
