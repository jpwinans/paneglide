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
    var preferencesModel: PreferencesModel?
    var helpWindow: NSWindow?
    var helpModel: HelpModel?
    let setup = SetupProgress()
    var practice = WindowPractice()
    var practiceIssue: String? { practice.step == .moveLeft || practice.step == .restore ? actionError : nil }
    let hotkeys = GlobalHotkeys()
    let login = LoginItem(system: NativeLoginSystem())
    private var actionError: String?
    private(set) var shortcutIssue: String?
    var shortcutReadiness: ShortcutReadiness {
        shortcutCommands.readiness(for: store.settings.shortcuts, enabled: store.settings.shortcutsEnabled)
    }
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
        retryShortcuts()
        if let message = store.recoveryNotice { showMessage(message) }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAccessStatus), name: NSApplication.didBecomeActiveNotification, object: nil)
        let needsSetup = setup.shouldPresent(accessibilityGranted: windows.trusted, hasSavedSettings: FileManager.default.fileExists(atPath: store.url.path) && store.recoveryNotice == nil, shortcuts: shortcutReadiness)
        if needsSetup || shortcutReadiness == .unavailable { showPermissionHelp() }
        else if store.settings.showPreferencesOnLaunch || ProcessInfo.processInfo.arguments.contains("--preferences") { showPreferences() }
    }
    func rebuildMenu() {
        if !store.settings.menuVisible {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        statusItem?.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "PaneGlide")
        statusItem?.button?.toolTip = "PaneGlide"
        let menu = NSMenu(); menu.delegate = self
        let shortcutStatus = shortcutReadiness == .unavailable ? "Shortcuts need attention — open Quick Start" : nil
        if let status = !windows.trusted ? "Accessibility access needed — open Quick Start" : (shortcutStatus ?? actionError) {
            let item = NSMenuItem(title: status, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item); menu.addItem(.separator())
        }
        let toggle = NSMenuItem(title: store.settings.shortcutsEnabled ? "Disable Shortcuts" : "Enable Shortcuts", action: #selector(toggleShortcuts), keyEquivalent: "")
        toggle.target = self; menu.addItem(toggle); menu.addItem(.separator())
        for action in WindowAction.allCases where !store.settings.hiddenActions.contains(action) {
            let shortcut = store.settings.shortcuts[action].map { "    " + $0.label } ?? ""
            let item = NSMenuItem(title: action.title + shortcut, action: #selector(performAction(_:)), keyEquivalent: "")
            item.representedObject = action.rawValue; item.target = self; menu.addItem(item)
            if [.down, .lowerRight, .center, .snapBack].contains(action) { menu.addItem(.separator()) }
        }
        menu.addItem(.separator())
        for (title, selector) in [("Preferences…", #selector(showPreferences)), ("View on GitHub…", #selector(showRepository)), ("Quick Start…", #selector(showPermissionHelp)), ("Help…", #selector(showHelp)), ("About PaneGlide…", #selector(showAbout))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        let quit = NSMenuItem(title: "Quit PaneGlide", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); quit.target = NSApp; menu.addItem(quit)
        statusItem?.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) { capturedTarget = (try? windows.focusedWindow())?.id }
    @objc func performAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = WindowAction(rawValue: raw) else { return }
        guard let capturedTarget else {
            actionError = WindowError.noWindow.localizedDescription
            helpModel?.refresh()
            rebuildMenu()
            return
        }
        run(action, target: capturedTarget)
    }
    func run(_ action: WindowAction, target: String? = nil) {
        do {
            let result = try commands.execute(action, target: target, settings: store.settings)
            practice.receive(action, result: result)
            actionError = nil
        } catch { actionError = error.localizedDescription }
        helpModel?.refresh()
        rebuildMenu()
    }
    func beginPractice() {
        practice.begin(); actionError = nil
        helpModel?.refresh()
    }
    func cancelPractice() {
        practice.cancel()
        helpModel?.refresh()
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
        helpModel?.refresh()
        rebuildMenu()
    }
    func retryShortcuts() {
        do {
            try shortcutCommands.apply(store.settings.shortcuts, enabled: store.settings.shortcutsEnabled)
            shortcutIssue = nil
        } catch { shortcutIssue = error.localizedDescription }
        helpModel?.refresh()
        rebuildMenu()
    }
    @objc private func refreshAccessStatus() { rebuildMenu() }
    @objc private func resetPressedKeys() { shortcutCommands.resetPressedKeys() }
    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        hotkeys.stop()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if helpWindow?.isVisible == true { NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil) }
        else { showPreferences() }
        return true
    }
    @objc func showPreferences() {
        if preferencesWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "PaneGlide Preferences"; window.isReleasedWhenClosed = false; window.delegate = self
            let model = PreferencesModel(controller: self)
            preferencesModel = model
            window.contentView = NSHostingView(rootView: PreferencesView(model: model))
            window.center(); preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); preferencesWindow?.makeKeyAndOrderFront(nil)
    }
    func editShortcuts() {
        showPreferences()
        preferencesModel?.page = .shortcuts
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === helpWindow {
            if practice.step == .moveLeft || practice.step == .restore { practice.cancel() }
            helpWindow = nil; helpModel = nil
        }
        if let window = notification.object as? NSWindow, window === preferencesWindow {
            preferencesWindow = nil; preferencesModel = nil
            retryShortcuts()
        }
    }
    @objc func showHelp() { showGuide(.guide) }
    @objc func showPermissionHelp() { showGuide(.setup) }
    private func showGuide(_ page: HelpModel.Page) {
        if helpWindow == nil {
            let model = HelpModel(controller: self, page: page)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 680), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "PaneGlide Help"; window.isReleasedWhenClosed = false; window.delegate = self
            window.contentView = NSHostingView(rootView: HelpView(model: model))
            window.center(); helpWindow = window; helpModel = model
        }
        helpModel?.page = page; helpModel?.refresh()
        NSApp.activate(ignoringOtherApps: true); helpWindow?.makeKeyAndOrderFront(nil)
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
                results.append(["case": label, "action": action.rawValue, "constrained": result.constrained, "actual": NSStringFromRect(result.actual), "expected": NSStringFromRect(result.requested), "seconds": Date.timeIntervalSinceReferenceDate - start])
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
        case .maximize: "Maximize"
        case .center: "Center"
        case .previousMonitor: "Previous Monitor"
        case .nextMonitor: "Next Monitor"
        case .snapBack: "SnapBack"
        }
    }
}
