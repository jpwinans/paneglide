import Foundation
import Testing
import PaneGlideCore

@Test func shortcutValidationAndPersistence() throws {
    try Shortcut.validate(Shortcut.defaults)
    #expect(Shortcut.defaults[.left] == Shortcut(123, modifiers: 7))
    #expect(Shortcut.defaults[.upperRight] == Shortcut(126, modifiers: 14))
    #expect(Shortcut.defaults[.snapBack] == Shortcut(44, modifiers: 7))
    #expect(throws: SettingsError.self) { try Shortcut.validate([.left: .init(123, modifiers: 7), .right: .init(123, modifiers: 7)]) }
    #expect(throws: SettingsError.self) { try Shortcut.validate([.left: .init(123, modifiers: 0)]) }
    #expect(throws: SettingsError.self) { try Shortcut.validate([.left: .init(56, modifiers: 7)]) }
    #expect(throws: SettingsError.self) { try Shortcut.validate([.left: .init(49, modifiers: 1)]) }
}

@Test func shortcutsRoundTripAndMigrate() throws {
    var settings = AppSettings()
    settings.shortcuts[.left] = Shortcut(0, modifiers: 5)
    settings.shortcuts[.right] = nil
    settings.shortcutsEnabled = false
    let data = try JSONEncoder().encode(settings)
    let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
    #expect(loaded.shortcuts[.left] == Shortcut(0, modifiers: 5))
    #expect(loaded.shortcuts[.right] == nil)
    #expect(!loaded.shortcutsEnabled)
    var oldDocument = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    oldDocument.removeValue(forKey: "shortcutBindings")
    let migrated = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: oldDocument))
    #expect(migrated.shortcuts == Shortcut.defaults)
    settings.layout.splitX = 0.6
    settings.shortcuts = Shortcut.defaults
    #expect(settings.layout.splitX == 0.6)
}

@MainActor private final class TestHotkeys: HotkeySystem {
    var tokens: [Shortcut: UInt32] = [:]
    var next: UInt32 = 0
    var rejected: Shortcut?
    func register(_ shortcut: Shortcut) throws -> UInt32 {
        if rejected == shortcut { throw SettingsError.invalid("Already registered") }
        next += 1; tokens[shortcut] = next; return next
    }
    func unregister(_ token: UInt32) { tokens = tokens.filter { $0.value != token } }
}

@Test @MainActor func shortcutsRecoverWhenSleepLosesKeyRelease() throws {
    let external = TestHotkeys()
    var actions: [WindowAction] = []
    let commands = ShortcutCommands(system: external) { actions.append($0) }
    let left = Shortcut(123, modifiers: 7)
    try commands.apply([.left: left], enabled: true)
    let token = try #require(external.tokens[left])
    commands.receive(token: token, pressed: true)
    commands.receive(token: token, pressed: true)
    #expect(actions == [.left])
    // macOS may sleep or lock before delivering the release event.
    commands.resetPressedKeys()
    commands.receive(token: token, pressed: true)
    commands.receive(token: token, pressed: true)
    #expect(actions == [.left, .left])
    #expect(external.tokens[left] == token)
}

@Test @MainActor func shortcutsAreTransactionalAndIgnoreHeldKeys() throws {
    let external = TestHotkeys()
    var actions: [WindowAction] = []
    let commands = ShortcutCommands(system: external) { actions.append($0) }
    let left = Shortcut(123, modifiers: 7)
    try commands.apply([.left: left], enabled: true)
    let token = try #require(external.tokens[left])
    commands.receive(token: token, pressed: true)
    commands.receive(token: token, pressed: true)
    #expect(actions == [.left])
    commands.receive(token: token, pressed: false)
    commands.receive(token: token, pressed: true)
    #expect(actions == [.left, .left])
    let rejected = Shortcut(0, modifiers: 5)
    external.rejected = rejected
    #expect(throws: SettingsError.self) { try commands.apply([.right: rejected], enabled: true) }
    #expect(external.tokens[left] == token)
    commands.receive(token: token, pressed: false)
    commands.receive(token: token, pressed: true)
    #expect(actions == [.left, .left, .left])
    try commands.apply([.left: left], enabled: false)
    #expect(external.tokens.isEmpty)
    commands.receive(token: token, pressed: true)
    #expect(actions.count == 3)
    try commands.apply([.right: left], enabled: true)
    commands.receive(token: try #require(external.tokens[left]), pressed: true)
    #expect(actions.last == .right)
}
