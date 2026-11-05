import AppKit
import SwiftUI
import ServiceManagement
import PaneGlideCore

@MainActor final class HelpModel: ObservableObject {
    enum Page { case setup, guide }
    @Published var page: Page
    @Published var accessibilityGranted: Bool
    @Published var loginState: LoginState
    @Published var settings: AppSettings
    @Published var shortcutReadiness: ShortcutReadiness
    @Published var shortcutIssue: String?
    @Published var message = ""
    unowned let controller: AppController

    init(controller: AppController, page: Page) {
        self.controller = controller; self.page = page
        accessibilityGranted = controller.windows.trusted
        loginState = controller.login.state; settings = controller.store.settings
        shortcutReadiness = controller.shortcutReadiness; shortcutIssue = controller.shortcutIssue
    }
    func refresh() {
        accessibilityGranted = controller.windows.trusted
        loginState = controller.login.state; settings = controller.store.settings
        shortcutReadiness = controller.shortcutReadiness; shortcutIssue = controller.shortcutIssue
    }
    func setLogin(_ enabled: Bool) {
        do { try controller.login.setEnabled(enabled); message = "" }
        catch { message = error.localizedDescription }
        refresh()
    }
    var canFinishSetup: Bool { controller.setup.canComplete(accessibilityGranted: accessibilityGranted, shortcuts: shortcutReadiness) }
    func finishSetup() {
        refresh()
        if controller.setup.complete(accessibilityGranted: accessibilityGranted, shortcuts: shortcutReadiness) { controller.helpWindow?.close() }
    }
    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

struct HelpView: View {
    @ObservedObject var model: HelpModel
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("PaneGlide").font(.largeTitle.bold())
                    Text("Your windows, a few keystrokes away.").foregroundStyle(.secondary)
                }
                Spacer()
            }
            TabView(selection: $model.page) {
                quickStart.tabItem { Label("Quick Start", systemImage: "sparkles") }.tag(HelpModel.Page.setup)
                guide.tabItem { Label("Using PaneGlide", systemImage: "book") }.tag(HelpModel.Page.guide)
            }
            HStack {
                Button("Edit Shortcuts…") { model.controller.editShortcuts() }
                Button("Preferences…") { model.controller.showPreferences() }
                Spacer()
                if model.page == .setup {
                    Button("Close") { model.controller.helpWindow?.close() }.keyboardShortcut(.cancelAction)
                    Button("Start Using PaneGlide", action: model.finishSetup)
                        .disabled(!model.canFinishSetup).keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") { model.controller.helpWindow?.close() }.keyboardShortcut(.cancelAction)
                }
            }
        }.padding(24).frame(minWidth: 600, idealWidth: 660, minHeight: 600, idealHeight: 680)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in model.refresh() }
    }
    private var quickStart: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("1. Allow window control") {
                    Label(model.accessibilityGranted ? "Accessibility access is enabled" : "Accessibility access is needed",
                          systemImage: model.accessibilityGranted ? "checkmark.circle.fill" : "lock")
                        .foregroundStyle(model.accessibilityGranted ? Color.green : Color.primary)
                    Text("PaneGlide needs Accessibility access to move and resize other apps’ windows. It does not record your screen.")
                    if !model.accessibilityGranted {
                        Text("In System Settings → Privacy & Security → Accessibility, enable PaneGlide. If it is missing, click + and select the installed app. Return here to check its status.")
                        HStack {
                            Button("Open Accessibility Settings…", action: model.openAccessibilitySettings)
                            Button("Show App in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                        }
                        Text("After rebuilding, if access still shows as off, remove PaneGlide from that list and add the installed app again.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                section("2. Check your shortcuts") {
                    shortcutStatus
                    Text("Click a window in another app, then press a shortcut. PaneGlide stays in your menu bar; it has no permanent Dock icon.")
                    shortcutRow(.left)
                    shortcutRow(.center)
                    shortcutRow(.snapBack)
                    Text("⌃ Control     ⌥ Option     ⇧ Shift     ⌘ Command").font(.caption).foregroundStyle(.secondary)
                    Text("Quit other window managers or disable their matching shortcuts first. Choose Edit Shortcuts below to view or change any binding.").font(.callout).foregroundStyle(.secondary)
                }
                section("3. Choose when to start") {
                    Toggle("Start PaneGlide automatically at login", isOn: Binding(get: { model.loginState == .enabled || model.loginState == .requiresApproval }, set: { model.setLogin($0) }))
                    Text("Optional. This switch takes effect immediately.").font(.caption).foregroundStyle(.secondary)
                    if model.loginState == .requiresApproval {
                        Text("macOS needs your approval in Login Items.")
                        Button("Open Login Items Settings…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    if !model.message.isEmpty { Text(model.message).foregroundStyle(.orange) }
                }
            }.padding(16)
        }
    }
    @ViewBuilder private var shortcutStatus: some View {
        switch model.shortcutReadiness {
        case .ready:
            Label("Shortcuts are ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .disabled:
            Text("Shortcuts are turned off. You can use menu actions, or enable shortcuts in Edit Shortcuts.")
        case .unassigned:
            Text("No shortcuts are assigned. You can use menu actions, or add bindings in Edit Shortcuts.")
        case .unavailable:
            Label("Shortcuts need attention", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            Text(model.shortcutIssue ?? "Shortcuts are not active. Finish recording a shortcut in Preferences, or choose Retry.")
            Text("Quit a competing window utility or change the conflicting binding in Edit Shortcuts, then retry. You can also turn shortcuts off there to use menu actions only.").font(.callout).foregroundStyle(.secondary)
            Button("Retry Shortcuts") { model.controller.retryShortcuts() }
        }
    }
    private var guide: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Move, resize, and restore") {
                    Text("Focus the window you want to arrange, then use a shortcut or choose an action from the PaneGlide menu. Left, Right, Up, and Down use your split sizes; corner actions use your quarter sizes. Center can also resize the window. Previous/Next Monitor move it to another display.")
                    Text("SnapBack restores that window’s position before its first successful PaneGlide move. Repeated SnapBack keeps that position; a later arrangement starts a new restore point.")
                }
                section("Make room on an ultrawide") {
                    Text("In Preferences → Window Sizes, choose a Center width and height, then enable Alternate Left and Alternate Right. Use percentages or fixed macOS points. Fit beside Center calculates each side’s remaining space for you.")
                    Text("Center your main window. Focus a side window and use Left twice: the first press uses your split, the next uses its alternate width. Repeat with Right for the other side. A third press returns to the split. Each command moves only the focused window.")
                }
                section("Make it yours") {
                    Text("Shortcuts: click a shortcut to record; Escape cancels and Delete clears. Each action can be shown or hidden in the menu.")
                    Text("Margins: set the space at screen edges and between windows. Partitions: choose separate horizontal and vertical dividers for splits and quarters.")
                    Text("On Margins, Partitions, or Window Sizes, choose Global defaults or a display with separate settings. Your laptop and monitor can use different layouts.")
                    Text("Advanced: choose proportional sizing between monitors, centering for windows with fixed sizes, and keeping windows in bounds. Some apps enforce minimum sizes or refuse resizing.")
                    Text("Choose Apply to save layout and shortcut changes. Import Saved Settings previews an exported JSON file; Apply saves it. Export Saved Settings backs up your saved configuration. Startup and Accessibility are set separately on each Mac.")
                }
                section("Need a hand?") {
                    Text("If nothing moves, check Quick Start for Accessibility status and make sure shortcuts are enabled. Try an ordinary resizable window outside macOS Full Screen. If a shortcut conflicts, change it or disable the other app’s matching shortcut.")
                    Text("If the menu icon is hidden, open PaneGlide from Finder to reach Preferences. To update, download a newer source release and run bash install.sh again. Settings are preserved.")
                    Link("Full guide and troubleshooting on GitHub", destination: URL(string: "https://github.com/jpwinans/paneglide/blob/main/docs/usage.md")!)
                }
            }.padding(16)
        }
    }
    private func shortcutRow(_ action: WindowAction) -> some View {
        HStack { Text(action.title); Spacer(); Text(model.settings.shortcuts[action]?.label ?? "Not assigned").monospaced().foregroundStyle(.secondary) }
            .accessibilityElement(children: .combine)
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox(title) { VStack(alignment: .leading, spacing: 10, content: content).frame(maxWidth: .infinity, alignment: .leading).padding(8) }
    }
}
