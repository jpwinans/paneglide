import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement
import PaneGlideCore

@MainActor final class PreferencesModel: ObservableObject {
    @Published var draft: AppSettings
    @Published var selectedDisplay = ""
    @Published var message = ""
    @Published var displays: [Display]
    @Published var loginState: LoginState
    @Published var accessibilityGranted: Bool
    unowned let controller: AppController
    init(controller: AppController) {
        self.controller = controller; draft = controller.store.settings; displays = controller.windows.displays(); loginState = controller.login.state; accessibilityGranted = controller.windows.trusted
    }
    func refreshSystemState() { loginState = controller.login.state; displays = controller.windows.displays(); accessibilityGranted = controller.windows.trusted }
    func setLogin(_ enabled: Bool) {
        do { try controller.login.setEnabled(enabled); message = "Login setting updated in macOS." }
        catch { message = error.localizedDescription }
        refreshSystemState()
    }
    var layout: LayoutSettings {
        get { selectedDisplay.isEmpty ? draft.layout : draft.layout(for: selectedDisplay) }
        set { if selectedDisplay.isEmpty { draft.layout = newValue } else { draft.displayLayouts[selectedDisplay] = newValue } }
    }
    var hasOverride: Bool { selectedDisplay.isEmpty || draft.displayLayouts[selectedDisplay] != nil }
    func apply() {
        do { try controller.saveSettings(draft); message = "Settings saved." }
        catch { message = error.localizedDescription }
    }
    func setShortcut(_ shortcut: Shortcut?, for action: WindowAction) {
        var updated = draft.shortcuts; updated[action] = shortcut
        do { try Shortcut.validate(updated); draft.shortcuts = updated; message = "" }
        catch { message = error.localizedDescription }
    }
    func recording(_ active: Bool) {
        do { try controller.shortcutCommands.apply(controller.store.settings.shortcuts, enabled: !active && controller.store.settings.shortcutsEnabled) }
        catch { message = error.localizedDescription }
    }
    func exportSettings() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "PaneGlide Settings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try controller.store.exportData().write(to: url, options: .atomic); message = "Saved settings exported." }
        catch { message = error.localizedDescription }
    }
    func importSettings() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let value = try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: url))
            try value.validate(); draft = value; message = "Imported into this preview. Choose Apply to save."
        } catch { message = error.localizedDescription }
    }
}

struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel
    private var geometry: Binding<LayoutSettings> { Binding(get: { model.layout }, set: { model.layout = $0 }) }
    var body: some View {
        VStack(spacing: 12) {
            TabView {
                general.tabItem { Label("General", systemImage: "gearshape") }
                shortcuts.tabItem { Label("Shortcuts", systemImage: "keyboard") }
                geometryPage { margins }.tabItem { Label("Margins", systemImage: "rectangle.inset.filled") }
                geometryPage { partitions }.tabItem { Label("Partitions", systemImage: "rectangle.split.2x2") }
                geometryPage { sizing }.tabItem { Label("Window Sizes", systemImage: "rectangle.split.3x1") }
                advanced.tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
            }
            Text(model.message).font(.callout).foregroundStyle(model.message == "Settings saved." ? .secondary : .primary).frame(maxWidth: .infinity, alignment: .leading).lineLimit(3).accessibilityLabel("Settings status: " + model.message)
            HStack {
                Button("Import…", action: model.importSettings)
                Button("Export Saved Settings…", action: model.exportSettings)
                Spacer()
                Button("Revert Unsaved Changes") { model.draft = model.controller.store.settings; model.message = "" }
                Button("Apply", action: model.apply).keyboardShortcut(.return, modifiers: .command)
            }
        }.padding(20).frame(minWidth: 800, idealWidth: 840, minHeight: 650, idealHeight: 700)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshSystemState() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in model.refreshSystemState() }
    }
    private var general: some View {
        Form {
            Section("Application") {
                Toggle("Start PaneGlide automatically at login", isOn: Binding(get: { model.loginState == .enabled || model.loginState == .requiresApproval }, set: model.setLogin))
                Text(loginDescription).font(.caption).foregroundStyle(.secondary)
                if model.loginState == .requiresApproval { Button("Open Login Items Settings…") { SMAppService.openSystemSettingsLoginItems() } }
                Toggle("Show preferences on launch", isOn: $model.draft.showPreferencesOnLaunch)
                Button("Accessibility Access…") { model.controller.showPermissionHelp() }
                HStack {
                    Text(model.accessibilityGranted ? "Accessibility access is enabled." : "Accessibility access is not available to this process.").foregroundStyle(model.accessibilityGranted ? Color.secondary : Color.orange)
                    Button("Refresh Access Status", action: model.refreshSystemState)
                }
                #if DEBUG
                Button("Run Disposable Fixture Checks (Debug)") { model.controller.runIntegrationTest(terminate: false); model.refreshSystemState() }
                #endif
                Text("Move and resize the frontmost window using shortcuts or the menu bar. Full Screen fills the usable desktop without creating a Space.").foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Toggle("Show PaneGlide in menu bar", isOn: $model.draft.menuVisible)
                Text("If you hide the icon, reopen PaneGlide from Finder to return to preferences.").font(.caption).foregroundStyle(.secondary)
                Toggle("Show tooltips", isOn: $model.draft.showTooltips)
                Toggle("Show visual action overlay", isOn: $model.draft.showOverlay)
            }
        }.formStyle(.grouped)
    }
    private var loginDescription: String {
        switch model.loginState {
        case .enabled: "Enabled in macOS. This switch takes effect immediately."
        case .disabled: "Disabled in macOS. This switch takes effect immediately."
        case .requiresApproval: "Approval is required in System Settings → General → Login Items."
        case .unavailable: "macOS has no available login registration for PaneGlide. Try enabling this switch to register it."
        }
    }
    private var shortcuts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable shortcuts", isOn: $model.draft.shortcutsEnabled)
                Text("Click a shortcut to record. Escape cancels; Delete clears it. Command, Option, or Control is required. Changes take effect when you choose Apply.").font(.callout).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 7) {
                    GridRow { Text("Action").bold(); Text("Shortcut").bold(); Text("Show in menu").bold() }
                    ForEach(WindowAction.allCases, id: \.self) { action in
                        GridRow {
                            Text(action.title).frame(width: 170, alignment: .leading)
                            ShortcutRecorder(shortcut: model.draft.shortcuts[action], name: action.title,
                                             changed: { model.setShortcut($0, for: action) }, recording: model.recording).frame(width: 190, height: 26)
                            Toggle(action.title, isOn: Binding(get: { !model.draft.hiddenActions.contains(action) }, set: { if $0 { model.draft.hiddenActions.remove(action) } else { model.draft.hiddenActions.insert(action) } })).labelsHidden().accessibilityLabel("Show \(action.title) in menu")
                        }
                    }
                }
                Button("Restore Default Shortcuts") { model.draft.shortcuts = Shortcut.defaults }
            }.padding(16)
        }
    }
    private func geometryPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Display settings", selection: $model.selectedDisplay) {
                    Text("Global defaults").tag("")
                    ForEach(model.displays.filter(\.supportsProfile), id: \.id) { Text($0.name).tag($0.id) }
                    ForEach(model.draft.displayLayouts.keys.filter { id in !model.displays.contains { $0.id == id } }.sorted(), id: \.self) { Text("Disconnected display: \($0)").tag($0) }
                }
                if model.displays.contains(where: { !$0.supportsProfile }) {
                    Text("A display could not be uniquely identified. It uses Global defaults; saved display profiles are retained.").foregroundStyle(.secondary)
                }
                if !model.selectedDisplay.isEmpty {
                    Toggle("Use separate settings for this display", isOn: Binding(get: { model.hasOverride }, set: { if $0 { model.draft.displayLayouts[model.selectedDisplay] = model.draft.layout } else { model.draft.displayLayouts.removeValue(forKey: model.selectedDisplay) } }))
                }
                content().disabled(!model.hasOverride)
                LayoutPreview(settings: model.layout, screen: model.displays.first(where: { $0.id == model.selectedDisplay })?.visibleFrame ?? model.displays.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 2000, height: 1000))
                Text("Percentages use the usable desktop after enabled edge margins. Fixed dimensions are macOS points, independent of Retina scaling.").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
    }
    private var margins: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Screen edge margins") {
                VStack(alignment: .leading) {
                    Toggle("Enable edge margins", isOn: geometry.margins.enabled)
                    HStack { number("Top", geometry.margins.top); number("Left", geometry.margins.left); number("Bottom", geometry.margins.bottom); number("Right", geometry.margins.right) }.disabled(!model.layout.margins.enabled)
                }.padding(8)
            }
            GroupBox("Space between windows") {
                VStack(alignment: .leading) {
                    Toggle("Enable partition gaps", isOn: geometry.gapsEnabled)
                    HStack { number("Horizontal", geometry.horizontalGap); number("Vertical", geometry.verticalGap) }.disabled(!model.layout.gapsEnabled)
                }.padding(8)
            }
        }
    }
    private var partitions: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Split screen partitions") {
                HStack { percentage("Left width", geometry.splitX); percentage("Upper height", geometry.splitY); Button("Reset Split") { geometry.wrappedValue.splitX = 0.5; geometry.wrappedValue.splitY = 0.5 } }.padding(8)
            }
            GroupBox("Quarter screen partitions") {
                HStack { percentage("Left width", geometry.quarterX); percentage("Upper height", geometry.quarterY); Button("Reset Quarters") { geometry.wrappedValue.quarterX = 0.5; geometry.wrappedValue.quarterY = 0.5 } }.padding(8)
            }
        }
    }
    private var sizing: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Center") {
                VStack(alignment: .leading) {
                    Toggle("Resize when centering", isOn: geometry.centerResize)
                    HStack { dimension("Width", geometry.centerWidth); dimension("Height", geometry.centerHeight) }.disabled(!model.layout.centerResize)
                }.padding(8)
            }
            GroupBox("Repeated Left and Right") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The first press uses your normal split. Press the same action again to use its alternate width, anchored to the screen edge. A third press returns to the normal split.").font(.callout)
                    side("Left", geometry.alternateLeft)
                    Toggle("Use the left alternate width for both sides", isOn: geometry.linkAlternateWidths)
                    side("Right", geometry.alternateRight, linked: model.layout.linkAlternateWidths)
                    Text("Fit beside Center follows your configured Center width and horizontal gap. It does not inspect or move any other window.").font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
        }
    }
    private func side(_ label: String, _ binding: Binding<AlternateWidth>, linked: Bool = false) -> some View {
        HStack {
            Toggle("Alternate \(label)", isOn: binding.enabled).frame(width: 145, alignment: .leading)
            dimension("Width", binding.width).disabled(linked || !binding.wrappedValue.enabled || binding.wrappedValue.fitBesideCenter)
            Toggle("Fit beside Center", isOn: binding.fitBesideCenter).disabled(linked || !binding.wrappedValue.enabled)
        }
    }
    private var advanced: some View {
        Form {
            Section("Multiple monitors") { Toggle("Resize windows proportionally when changing monitors", isOn: $model.draft.resizeProportionally) }
            Section("Best-effort behavior") {
                Toggle("Center windows that do not resize fully", isOn: $model.draft.centerConstrainedWindows)
                Toggle("Try to keep windows in bounds", isOn: $model.draft.keepInBounds)
                Toggle("Account for attached legacy drawers", isOn: $model.draft.accountForDrawers)
                Text("Applies to apps exposing an attached AXDrawer with usable bounds. Modern sidebars are part of their parent window.").font(.caption).foregroundStyle(.secondary)
                Text("Applications can impose minimum sizes or fixed dimensions. PaneGlide reads the actual result and reports a constraint when the requested layout cannot be reached.").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    private func number(_ title: String, _ value: Binding<Double>) -> some View {
        HStack { Text(title); NumberInput(value: value).accessibilityLabel(title + " points").frame(width: 65); Text("pt").foregroundStyle(.secondary) }
            .help(model.draft.showTooltips ? "Distance in logical macOS points." : "")
    }
    private func percentage(_ title: String, _ value: Binding<Double>) -> some View {
        HStack { Text(title); NumberInput(value: Binding(get: { value.wrappedValue * 100 }, set: { value.wrappedValue = $0 / 100 })).accessibilityLabel(title + " percent").frame(width: 65); Text("%") }
            .help(model.draft.showTooltips ? "Divider position as a percentage of the usable desktop." : "")
    }
    private func dimension(_ title: String, _ value: Binding<PaneGlideCore.Dimension>) -> some View {
        HStack {
            Text(title); NumberInput(value: value.value).accessibilityLabel(title).frame(width: 65)
            Picker(title + " units", selection: value.unit) { Text("%").tag(SizeUnit.percent); Text("points").tag(SizeUnit.points) }.labelsHidden().frame(width: 90)
        }.help(model.draft.showTooltips ? "Choose a percentage of usable desktop size or fixed macOS points." : "")
    }
}

private struct NumberInput: View {
    @Binding var value: Double
    @State private var text = ""
    var body: some View {
        TextField("", text: $text).textFieldStyle(.roundedBorder)
            .onAppear { text = value.formatted(.number.grouping(.never)) }
            .onChange(of: text) { _, new in value = Double(new) ?? .nan }
            .onChange(of: value) { _, new in
                if new.isFinite && Double(text) != new { text = new.formatted(.number.grouping(.never)) }
            }
    }
}

private struct LayoutPreview: View {
    let settings: LayoutSettings
    let screen: CGRect
    var body: some View {
        VStack(alignment: .leading) {
            Text("Preview: alternate sides and Center").font(.caption)
            if (try? settings.validate(screen: screen)) != nil {
                GeometryReader { proxy in
                    let scale = min(proxy.size.width / screen.width, proxy.size.height / screen.height)
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(.quaternary)
                        ForEach([WindowAction.left, .right, .center], id: \.self) { action in
                            let first = Layout.frame(for: action, current: .zero, screen: screen, settings: settings)
                            let frame = action == .center ? first : Layout.frame(for: action, current: first, screen: screen, settings: settings)
                            Rectangle().fill(action == .center ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.3)).border(.primary.opacity(0.4)).frame(width: frame.width * scale, height: frame.height * scale).offset(x: (frame.minX - screen.minX) * scale, y: (frame.minY - screen.minY) * scale)
                        }
                    }.frame(width: screen.width * scale, height: screen.height * scale)
                }.frame(height: 145).accessibilityLabel("Preview of the configured Center and side windows")
            } else { Text("Enter valid sizes to display a preview.").foregroundStyle(.secondary) }
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: Shortcut?
    let name: String
    let changed: (Shortcut?) -> Void
    let recording: (Bool) -> Void
    func makeNSView(context: Context) -> RecorderButton { RecorderButton() }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.changed = changed; button.recordingChanged = recording
        button.savedTitle = shortcut?.label ?? "Record Shortcut"
        if !button.recording { button.title = button.savedTitle }
        button.setAccessibilityLabel("Shortcut for \(name): \(button.savedTitle)")
    }
}

@MainActor private final class RecorderButton: NSButton {
    var changed: ((Shortcut?) -> Void)?
    var recordingChanged: ((Bool) -> Void)?
    var recording = false
    var savedTitle = "Record Shortcut"
    override var acceptsFirstResponder: Bool { true }
    init() { super.init(frame: .zero); bezelStyle = .rounded; target = self; action = #selector(beginRecording) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc func beginRecording() {
        window?.makeFirstResponder(self); recording = true; title = "Press shortcut…"; recordingChanged?(true)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode != 53 {
            let shortcut = Shortcut(event: event)
            changed?(event.keyCode == 51 && shortcut.modifiers == 0 ? nil : shortcut)
        }
        finish()
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
    override func resignFirstResponder() -> Bool { finish(); return super.resignFirstResponder() }
    private func finish() { guard recording else { return }; recording = false; title = savedTitle; recordingChanged?(false) }
}
