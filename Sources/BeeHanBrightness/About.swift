#if canImport(AppKit)
import AppKit

var about: NSWindow?
extension NSApplication {
    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://bhb.zolfer.com/")!) }
    @objc func openAuthor() { NSWorkspace.shared.open(URL(string: "https://zolfer.com/")!) }
    @objc func openCoffee() { NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/zolfer")!) }
    @objc func showAbout() {
        if about == nil {
            let logo = NSImageView(image: applicationIconImage)
            logo.widthAnchor.constraint(equalToConstant: 96).isActive = true
            logo.heightAnchor.constraint(equalToConstant: 96).isActive = true
            let name = NSTextField(labelWithString: "BeeHan Brightness")
            name.font = .boldSystemFont(ofSize: 16)
            let author = NSButton(title: "Zolfer Figueiredo", target: self, action: #selector(openAuthor))
            author.isBordered = false
            author.contentTintColor = .linkColor
            let by = NSStackView(views: [NSTextField(labelWithString: tr("by")), author])
            by.spacing = 3
            for case let view as NSControl in by.views { view.font = .systemFont(ofSize: NSFont.smallSystemFontSize) }
            let number = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let version = NSTextField(labelWithString: tr("version", ["version": number]))
            let check = NSButton(title: tr("check"), target: self, action: #selector(checkNow))
            let line = NSBox()
            line.boxType = .separator
            let site = NSButton(title: tr("website"), target: self, action: #selector(openSite))
            site.isBordered = false
            site.contentTintColor = .linkColor
            let liked = NSTextField(labelWithString: tr("liked"))
            let coffee = NSButton(title: tr("coffee"), target: self, action: #selector(openCoffee))
            let page = NSStackView(views: [logo, name, by, version, check, line, site, liked, coffee])
            page.orientation = .vertical
            page.spacing = 4
            page.setCustomSpacing(12, after: logo)
            for view in [name, by] { page.setCustomSpacing(10, after: view) }
            page.setCustomSpacing(16, after: version)
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
            about = w
        }
        activate(ignoringOtherApps: true) // a menu bar app is never frontmost on its own
        about?.makeKeyAndOrderFront(nil)
    }
}
#endif
