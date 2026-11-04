import AppKit

@MainActor final class Fixture: NSObject, NSApplicationDelegate, NSWindowDelegate, @preconcurrency NSDrawerDelegate {
    var window: NSWindow!
    var drawer: NSDrawer?
    var extraWindows: [NSWindow] = []
    var lastCommand = ""
    func applicationDidFinishLaunching(_ notification: Notification) {
        let area = NSScreen.screens.first?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        window = NSWindow(contentRect: NSRect(x: area.minX + 40, y: area.minY + 40, width: min(700, area.width - 100), height: min(500, area.height - 100)), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "PaneGlide Test Window"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        let label = NSTextField(labelWithString: "Disposable window for PaneGlide compatibility tests.\nNo user content is loaded here.")
        label.frame = NSRect(x: 20, y: 180, width: 600, height: 70)
        window.contentView?.addSubview(label)
        let drawerButton = NSButton(title: "Toggle Test Drawer", target: self, action: #selector(toggleDrawer))
        drawerButton.frame = NSRect(x: 20, y: 30, width: 190, height: 32)
        window.contentView?.addSubview(drawerButton)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--fixed") { window.styleMask.remove(.resizable) }
        if arguments.contains("--minimum") {
            window.contentMinSize = NSSize(width: 900, height: 600)
            window.setContentSize(NSSize(width: 1000, height: 700))
        }
        if arguments.contains("--aspect") {
            window.contentAspectRatio = NSSize(width: 16, height: 9)
            window.setContentSize(NSSize(width: 800, height: 450))
        }
        if arguments.contains("--increments") { window.contentResizeIncrements = NSSize(width: 10, height: 20) }
        if arguments.contains("--multiple") {
            for index in 0..<3 {
                extraWindows.append(makeExtraWindow(NSRect(x: area.minX + CGFloat(100 + index * 60), y: area.minY + CGFloat(80 + index * 30), width: min(600, area.width - 300), height: min(400, area.height - 200))))
            }
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(workflowCommand(_:)), name: .init("com.jpwinans.size-up.fixture.workflow"), object: nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(setDrawerState(_:)), name: .init("com.jpwinans.size-up.fixture.drawer"), object: nil)
        if arguments.contains("--drawer") { toggleDrawer() }
        record()
    }
    func makeExtraWindow(_ rect: NSRect) -> NSWindow {
        let extra = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        extra.title = "PaneGlide Test Window" // Deliberately equal titles.
        extra.delegate = self; extra.isReleasedWhenClosed = false; extra.isRestorable = false
        extra.orderFront(nil)
        return extra
    }
    @objc func workflowCommand(_ notification: Notification) {
        guard let command = notification.object as? String else { return }
        if command == "rename" { window.title = "Renamed PaneGlide Test Window" }
        else if command == "replace", let first = extraWindows.first {
            first.close()
            extraWindows.append(makeExtraWindow(NSRect(x: 500, y: 220, width: 620, height: 430)))
        } else { return }
        lastCommand = command; record()
    }
    @objc func toggleDrawer() {
        if drawer == nil {
            let drawer = NSDrawer(contentSize: NSSize(width: 180, height: 300), preferredEdge: .minX)
            drawer.parentWindow = window; drawer.delegate = self
            drawer.contentView = NSTextField(labelWithString: "Legacy drawer fixture")
            self.drawer = drawer
        }
        drawer?.toggle(nil)
    }
    @objc func setDrawerState(_ notification: Notification) {
        if notification.object as? String == "open" {
            if drawer == nil { toggleDrawer() } else { drawer?.open() }
        } else if notification.object as? String == "close" { drawer?.close() }
    }
    func drawerDidOpen(_ notification: Notification) { record() }
    func drawerDidClose(_ notification: Notification) { record() }
    func windowDidMove(_ notification: Notification) { record() }
    func windowDidResize(_ notification: Notification) { record() }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === window { NSApp.terminate(nil) }
        else { extraWindows.removeAll { $0 === notification.object as? NSWindow }; record() }
    }
    func record() {
        guard let window else { return }
        let rect: (NSRect) -> [Double] = { [$0.origin.x, $0.origin.y, $0.width, $0.height] }
        var data: [String: Any] = ["frame": rect(window.frame), "screens": NSScreen.screens.map { ["name": $0.localizedName, "frame": rect($0.frame), "visible": rect($0.visibleFrame)] }]
        if !extraWindows.isEmpty {
            data["windows"] = ([window] + extraWindows).map { ["number": $0.windowNumber, "frame": rect($0.frame)] as [String: Any] }
            data["lastCommand"] = lastCommand
        }
        if let drawer {
            data["drawerState"] = drawer.state
            data["drawerAXRole"] = drawer.accessibilityRole()?.rawValue
            data["drawerAXFrame"] = rect(drawer.accessibilityFrame())
            if let attachedWindow = drawer.contentView?.window {
                data["drawerWindowRole"] = attachedWindow.accessibilityRole()?.rawValue
                data["drawerWindowFrame"] = rect(attachedWindow.frame)
                data["drawerParentIsWindow"] = (attachedWindow.accessibilityParent() as AnyObject?) === window
                data["drawerParentType"] = String(describing: type(of: attachedWindow.accessibilityParent()))
            }
            let children: [Any] = window.accessibilityChildren() ?? []
            data["windowChildRoles"] = children.compactMap { ($0 as? NSAccessibilityProtocol)?.accessibilityRole()?.rawValue }
            let applicationWindows: [Any] = NSApp.accessibilityWindows() ?? []
            data["applicationWindowRoles"] = applicationWindows.compactMap { ($0 as? NSAccessibilityProtocol)?.accessibilityRole()?.rawValue }
        }
        if let json = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) {
            try? json.write(to: URL(fileURLWithPath: "/private/tmp/paneglide-fixture.json"), options: .atomic)
        }
    }
}
let app = NSApplication.shared
let delegate = Fixture()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
