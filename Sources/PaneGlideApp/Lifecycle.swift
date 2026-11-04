import AppKit
import ServiceManagement
import PaneGlideCore

@MainActor final class NativeLoginSystem: LoginSystem {
    var state: LoginState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
    func enable() throws { try SMAppService.mainApp.register() }
    func disable() throws { try SMAppService.mainApp.unregister() }
}

@MainActor private final class TaskCancellation: Cancellation {
    let task: Task<Void, Never>
    init(_ task: Task<Void, Never>) { self.task = task }
    func cancel() { task.cancel() }
}
@MainActor final class NativeDelay: DelayScheduler {
    func after(_ seconds: TimeInterval, perform: @escaping @MainActor () -> Void) -> any Cancellation {
        TaskCancellation(Task { @MainActor in
            do { try await Task.sleep(for: .seconds(seconds)); try Task.checkCancellation(); perform() }
            catch { /* Cancelled when replaced or hidden. */ }
        })
    }
}
@MainActor private final class FeedbackPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor final class NativeOverlay: OverlaySurface {
    private var panel: FeedbackPanel?
    func show(_ message: String) {
        if panel == nil {
            let panel = FeedbackPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 96), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            self.panel = panel
        }
        guard let panel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let background = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        background.material = .hudWindow; background.blendingMode = .behindWindow; background.state = .active
        background.wantsLayer = true; background.layer?.cornerRadius = 14
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: 15, weight: .medium); label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16), label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16), label.centerYAnchor.constraint(equalTo: background.centerYAnchor)])
        panel.contentView = background
        let area = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: area.midX - panel.frame.width / 2, y: area.minY + 48))
        panel.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil) }
}
