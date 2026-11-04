import Foundation
import Testing
import PaneGlideCore

@MainActor private final class TestCancellation: Cancellation { var cancelled = false; func cancel() { cancelled = true } }
@MainActor private final class TestDelay: DelayScheduler {
    var work: [(TimeInterval, @MainActor () -> Void, TestCancellation)] = []
    func after(_ seconds: TimeInterval, perform: @escaping @MainActor () -> Void) -> any Cancellation {
        let token = TestCancellation(); work.append((seconds, perform, token)); return token
    }
}
@MainActor private final class TestOverlay: OverlaySurface {
    var message: String?
    func show(_ message: String) { self.message = message }
    func hide() { message = nil }
}
@Test @MainActor func overlayExpiresWithoutStaleTimersHidingNewActions() throws {
    let surface = TestOverlay(); let clock = TestDelay()
    let feedback = ActionFeedback(surface: surface, scheduler: clock)
    feedback.show("Left")
    #expect(surface.message == "Left")
    let first = try #require(clock.work.first)
    #expect(first.0 == 1.2)
    feedback.show("Right")
    #expect(first.2.cancelled)
    first.1()
    #expect(surface.message == "Right")
    try #require(clock.work.last).1()
    #expect(surface.message == nil)
    feedback.show("Hidden", enabled: false)
    #expect(surface.message == nil)
    feedback.show("New")
    feedback.hide()
    #expect(surface.message == nil)
    #expect(clock.work.last?.2.cancelled == true)
}

@MainActor private final class TestLogin: LoginSystem {
    var state: LoginState = .disabled
    var deny = false
    var nextState: LoginState = .enabled
    func enable() throws { if deny { throw SettingsError.invalid("Denied") }; state = nextState }
    func disable() throws { if deny { throw SettingsError.invalid("Denied") }; state = .disabled }
}
@Test @MainActor func loginReflectsActualSystemStateAndDenial() throws {
    let external = TestLogin(); let login = LoginItem(system: external)
    external.nextState = .requiresApproval
    try login.setEnabled(true)
    #expect(login.state == .requiresApproval)
    external.state = .enabled
    #expect(login.state == .enabled)
    external.deny = true
    #expect(throws: SettingsError.self) { try login.setEnabled(false) }
    #expect(login.state == .enabled)
    external.deny = false
    try login.setEnabled(false)
    #expect(login.state == .disabled)
}
