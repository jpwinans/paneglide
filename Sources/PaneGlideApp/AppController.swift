import AppKit
import SwiftUI
import PaneGlideCore

@MainActor final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let windows = AccessibilityWindows()
    lazy var commands = WindowCommands(system: windows)
    var store: SettingsStore!
    var statusItem: NSStatusItem?
    var capturedTarget: String?
    var preferencesWindow: NSWindow?
    let hotkeys = GlobalHotkeys()
    let login = LoginItem(system: NativeLoginSystem())
    let feedback = ActionFeedback(surface: NativeOverlay(), scheduler: NativeDelay())
    lazy var shortcutCommands = ShortcutCommands(system: hotkeys) { [weak self] action in self?.run(action) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            store = try SettingsStore(
                url: support.appendingPathComponent("PaneGlide/settings.json"),
                legacyURL: support.appendingPathComponent("Size Up/settings.json")
            )
        } catch { showError(error); NSApp.terminate(nil); return }
        rebuildMenu()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--integration-workflow-test") { runWorkflowTest(); return }
        if ProcessInfo.processInfo.arguments.contains("--integration-test") { runIntegrationTest(); return }
        #endif
        hotkeys.onEvent = { [weak self] token, pressed in self?.shortcutCommands.receive(token: token, pressed: pressed) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(resetPressedKeys), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(resetPressedKeys), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        do { try shortcutCommands.apply(store.settings.shortcuts, enabled: store.settings.shortcutsEnabled) }
        catch { showError(error) }
        if let message = store.recoveryNotice { showMessage(message) }
        if !windows.trusted && !UserDefaults.standard.bool(forKey: "accessibilityExplained") {
            UserDefaults.standard.set(true, forKey: "accessibilityExplained")
            showPermissionHelp()
        }
        if store.settings.showPreferencesOnLaunch || ProcessInfo.processInfo.arguments.contains("--preferences") { showPreferences() }
    }
    func rebuildMenu() {
        if !store.settings.menuVisible {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        statusItem?.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "PaneGlide")
        statusItem?.button?.toolTip = store.settings.showTooltips ? "PaneGlide" : nil
        let menu = NSMenu(); menu.delegate = self
        let toggle = NSMenuItem(title: store.settings.shortcutsEnabled ? "Disable Shortcuts" : "Enable Shortcuts", action: #selector(toggleShortcuts), keyEquivalent: "")
        toggle.target = self; menu.addItem(toggle); menu.addItem(.separator())
        for action in WindowAction.allCases where !store.settings.hiddenActions.contains(action) {
            let shortcut = store.settings.shortcuts[action].map { "    " + $0.label } ?? ""
            let item = NSMenuItem(title: action.title + shortcut, action: #selector(performAction(_:)), keyEquivalent: "")
            item.representedObject = action.rawValue; item.target = self; menu.addItem(item)
            if [.down, .lowerRight, .center, .snapBack].contains(action) { menu.addItem(.separator()) }
        }
        menu.addItem(.separator())
        for (title, selector) in [("Preferences…", #selector(showPreferences)), ("View on GitHub…", #selector(showRepository)), ("Accessibility Access…", #selector(showPermissionHelp)), ("Help…", #selector(showHelp)), ("About PaneGlide…", #selector(showAbout))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        let quit = NSMenuItem(title: "Quit PaneGlide", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quit.target = NSApp; menu.addItem(quit)
        statusItem?.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) { capturedTarget = (try? windows.focusedWindow())?.id }
    @objc func performAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = WindowAction(rawValue: raw) else { return }
        guard let capturedTarget else { feedback.show(WindowError.noWindow.localizedDescription, duration: 3); return }
        run(action, target: capturedTarget)
    }
    func run(_ action: WindowAction, target: String? = nil) {
        do {
            let result = try commands.execute(action, target: target, settings: store.settings)
            feedback.show(result.constrained ? "\(action.title): this app limited the requested size." : action.title, enabled: store.settings.showOverlay)
        } catch { feedback.show(error.localizedDescription, duration: 5) }
    }
    @objc func toggleShortcuts() {
        var value = store.settings; value.shortcutsEnabled.toggle()
        do { try saveSettings(value) } catch { showError(error) }
    }
    func saveSettings(_ value: AppSettings) throws {
        try value.validate()
        for display in windows.displays() { try value.layout(for: display).validate(screen: display.visibleFrame) }
        try shortcutCommands.apply(value.shortcuts, enabled: value.shortcutsEnabled)
        do { try store.update(value) }
        catch {
            try? shortcutCommands.apply(store.settings.shortcuts, enabled: store.settings.shortcutsEnabled)
            throw error
        }
        rebuildMenu()
        if !value.showOverlay { feedback.hide() }
    }
    @objc private func resetPressedKeys() { shortcutCommands.resetPressedKeys() }
    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hotkeys.stop(); feedback.hide()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPreferences(); return true }
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "PaneGlide Preferences"; window.isReleasedWhenClosed = false; window.delegate = self
            window.contentView = NSHostingView(rootView: PreferencesView(model: PreferencesModel(controller: self)))
            window.center(); preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); preferencesWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === preferencesWindow {
            preferencesWindow = nil
            do { try shortcutCommands.apply(store.settings.shortcuts, enabled: store.settings.shortcutsEnabled) } catch { showError(error) }
        }
    }
    @objc func showHelp() {
        showMessage("Choose Preferences to customize shortcuts, margins, partitions, Center size, and repeated Left/Right widths. Use Apply to save. Reopen PaneGlide from Finder if you hide its menu icon. SnapBack restores the window’s initial position and size before your sequence of actions. Only one window utility should use a given shortcut.")
    }
    @objc func showPermissionHelp() {
        if windows.trusted { showMessage("Accessibility access is enabled. PaneGlide can control supported application windows."); return }
        windows.requestPermission()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        showMessage("Enable PaneGlide in Privacy & Security → Accessibility. If it is already enabled after replacing a development build, quit PaneGlide and reopen it from Finder. Use Refresh Access Status in preferences to check the actual result.")
    }
    @objc func showRepository() {
        NSWorkspace.shared.open(URL(string: "https://github.com/jpwinans/paneglide")!)
    }
    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PaneGlide"])
    }
    func showError(_ error: Error) { showMessage(error.localizedDescription) }
    func showMessage(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "PaneGlide"; alert.informativeText = message; alert.runModal()
    }
    #if DEBUG
    func runIntegrationTest(terminate: Bool = true) {
        let output = URL(fileURLWithPath: "/private/tmp/paneglide-native-test.json")
        var report: [String: Any] = ["trusted": windows.trusted, "bundle": Bundle.main.bundleURL.path, "timestamp": Date().description]
        var results: [[String: Any]] = []
        do {
            guard let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.jpwinans.size-up.fixture").first else { throw WindowError.noWindow }
            let target = try windows.firstWindow(pid: fixture.processIdentifier)
            report["drawerInsets"] = [target.drawerInsets.top, target.drawerInsets.left, target.drawerInsets.bottom, target.drawerInsets.right]
            defer {
                let restored = try? windows.apply(target.frame, to: target.id)
                report["restored"] = restored?.frame.approximatelyEquals(target.frame) ?? false
            }
            let displays = windows.displays()
            report["displayCount"] = displays.count
            var settings = AppSettings()
            settings.layout.alternateLeft.enabled = true
            settings.layout.alternateRight.enabled = true
            func check(_ action: WindowAction, monitor: Int? = nil, label: String) throws {
                let start = Date.timeIntervalSinceReferenceDate
                let result = try commands.execute(action, target: target.id, onMonitor: monitor, settings: settings)
                let insets = try windows.window(id: target.id).drawerInsets
                results.append(["case": label, "action": action.rawValue, "constrained": result.constrained, "actual": NSStringFromRect(result.actual), "expected": NSStringFromRect(result.requested), "drawerInsets": [insets.top, insets.left, insets.bottom, insets.right], "seconds": Date.timeIntervalSinceReferenceDate - start])
            }
            for index in displays.indices {
                let label = "display-\(index + 1)"
                try check(.maximize, monitor: index + 1, label: label)
                for action in [WindowAction.left, .left, .left, .right, .right, .right, .up, .down, .upperLeft, .upperRight, .lowerLeft, .lowerRight, .maximize, .center, .nextMonitor, .previousMonitor, .snapBack] {
                    try check(action, label: label)
                }
                for (width, height, side) in [(60.0, 80.0, 20.0), (40, 60, 30)] {
                    settings.layout.centerWidth = Dimension(width); settings.layout.centerHeight = Dimension(height)
                    settings.layout.alternateLeft.width = Dimension(side); settings.layout.alternateRight.width = Dimension(side)
                    for action in [WindowAction.center, .left, .left, .right, .right] {
                        try check(action, monitor: index + 1, label: "\(label)-center-\(width)x\(height)")
                    }
                }
                settings.layout = LayoutSettings()
                settings.layout.alternateLeft.enabled = true; settings.layout.alternateRight.enabled = true
            }
            report["passed"] = !results.isEmpty && results.allSatisfy { $0["constrained"] as? Bool == false }
            if ProcessInfo.processInfo.arguments.contains("--drawer-checks") {
                var phases: [[String: Any]] = []
                func setDrawer(open: Bool) throws {
                    DistributedNotificationCenter.default().postNotificationName(.init("com.jpwinans.size-up.fixture.drawer"), object: open ? "open" : "close", userInfo: nil, deliverImmediately: true)
                    let deadline = Date().addingTimeInterval(2)
                    while Date() < deadline {
                        let data = try Data(contentsOf: URL(fileURLWithPath: "/private/tmp/paneglide-fixture.json"))
                        let fixtureState = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        if fixtureState?["drawerState"] as? Int == (open ? 2 : 0) { return }
                        Thread.sleep(forTimeInterval: 0.025)
                    }
                    throw SettingsError.invalid("The disposable drawer did not finish opening or closing.")
                }
                settings = AppSettings()
                for (name, open, account) in [("closed", false, true), ("open-ignored", true, false), ("open-reserved", true, true)] {
                    try setDrawer(open: open)
                    settings.accountForDrawers = account
                    let result = try commands.execute(.left, target: target.id, onMonitor: 1, settings: settings)
                    let insets = try windows.window(id: target.id).drawerInsets
                    phases.append(["phase": name, "actual": [result.actual.minX, result.actual.minY, result.actual.width, result.actual.height], "drawerInsets": [insets.top, insets.left, insets.bottom, insets.right]])
                }
                report["drawerPhases"] = phases
            }
        } catch { report["error"] = error.localizedDescription }
        report["results"] = results
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: output, options: .atomic) }
        if terminate { NSApp.terminate(nil) }
        else { showMessage("Fixture check completed. Results: /private/tmp/paneglide-native-test.json\n\(report["error"] as? String ?? (report["passed"] as? Bool == true ? "All requested frames matched." : "A window constrained the requested layout."))") }
    }
    #endif
}

extension WindowAction {
    var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .up: "Up"
        case .down: "Down"
        case .upperLeft: "Upper Left"
        case .upperRight: "Upper Right"
        case .lowerLeft: "Lower Left"
        case .lowerRight: "Lower Right"
        case .maximize: "Full Screen"
        case .center: "Center"
        case .previousMonitor: "Previous Monitor"
        case .nextMonitor: "Next Monitor"
        case .snapBack: "SnapBack"
        }
    }
}
