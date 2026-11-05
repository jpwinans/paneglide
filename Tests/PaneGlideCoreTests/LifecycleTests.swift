import Foundation
import Testing
import PaneGlideCore

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
