#if canImport(AppKit)
import AppKit

var about: NSWindow?
extension NSApplication {
    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://bhb.zolfer.com/")!) }
    @objc func openAuthor() { NSWorkspace.shared.open(URL(string: "http://zolfer.com/")!) }
    @objc func showAbout() {
        if about == nil {
            let name = NSTextField(labelWithString: "BeeHan Brightness")
            name.font = .boldSystemFont(ofSize: 16)
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            let site = NSButton(title: "Website", target: self, action: #selector(openSite))
            site.isBordered = false
            site.contentTintColor = .linkColor
            let author = NSButton(title: "Zolfer Figueiredo", target: self, action: #selector(openAuthor))
            author.isBordered = false
            author.contentTintColor = .linkColor
            let by = NSStackView(views: [NSTextField(labelWithString: "By"), author])
            by.spacing = 3
            let text = NSStackView(views: [name, by,
                                           NSTextField(labelWithString: "Version \(version)"), site])
            text.orientation = .vertical
            text.setCustomSpacing(12, after: name)
            let logo = NSImageView(image: applicationIconImage)
            logo.widthAnchor.constraint(equalToConstant: 96).isActive = true
            logo.heightAnchor.constraint(equalToConstant: 96).isActive = true
            let row = NSStackView(views: [logo, text])
            row.spacing = 24
            row.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 24, right: 40)
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.contentView = row
            w.setContentSize(row.fittingSize)
            w.isReleasedWhenClosed = false
            w.center()
            about = w
        }
        activate(ignoringOtherApps: true) // a menu bar app is never frontmost on its own
        about?.makeKeyAndOrderFront(nil)
    }
}
#endif
