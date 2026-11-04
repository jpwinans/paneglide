import Foundation

public struct Shortcut: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    /// Command = 1, Option = 2, Control = 4, Shift = 8.
    public var modifiers: UInt32
    public init(_ keyCode: UInt32, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let defaults: [WindowAction: Shortcut] = [
        .left: .init(123, modifiers: 7), .right: .init(124, modifiers: 7),
        .up: .init(126, modifiers: 7), .down: .init(125, modifiers: 7),
        .upperLeft: .init(123, modifiers: 14), .upperRight: .init(126, modifiers: 14),
        .lowerLeft: .init(125, modifiers: 14), .lowerRight: .init(124, modifiers: 14),
        .previousMonitor: .init(123, modifiers: 6), .nextMonitor: .init(124, modifiers: 6),
        .maximize: .init(46, modifiers: 7), .center: .init(8, modifiers: 7), .snapBack: .init(44, modifiers: 7)
    ]
    public static func validate(_ bindings: [WindowAction: Shortcut]) throws {
        var seen: Set<Shortcut> = []
        for shortcut in bindings.values {
            guard shortcut.keyCode <= 126, !(54...63).contains(shortcut.keyCode),
                  shortcut.modifiers & 7 != 0, shortcut.modifiers & ~15 == 0 else {
                throw SettingsError.invalid("Choose a key with Command, Option, or Control; modifier-only shortcuts are unsupported.")
            }
            guard !(shortcut.modifiers == 1 && [48, 49].contains(shortcut.keyCode)) else {
                throw SettingsError.invalid("Command-Tab and Command-Space are reserved by macOS.")
            }
            guard seen.insert(shortcut).inserted else { throw SettingsError.invalid("Two actions cannot use the same shortcut.") }
        }
    }
}

@MainActor public protocol HotkeySystem: AnyObject {
    func register(_ shortcut: Shortcut) throws -> UInt32
    func unregister(_ token: UInt32)
}

@MainActor public final class ShortcutCommands {
    private let system: any HotkeySystem
    private let perform: (WindowAction) -> Void
    private var registrations: [Shortcut: UInt32] = [:]
    private var actions: [UInt32: WindowAction] = [:]
    private var held: Set<UInt32> = []
    public init(system: any HotkeySystem, perform: @escaping (WindowAction) -> Void) { self.system = system; self.perform = perform }
    public func apply(_ bindings: [WindowAction: Shortcut], enabled: Bool) throws {
        try Shortcut.validate(bindings)
        let desired = enabled ? bindings : [:]
        var additions: [Shortcut: UInt32] = [:]
        do {
            for shortcut in desired.values where registrations[shortcut] == nil {
                additions[shortcut] = try system.register(shortcut)
            }
        } catch {
            additions.values.forEach(system.unregister)
            throw error
        }
        for (shortcut, token) in registrations where !desired.values.contains(shortcut) {
            system.unregister(token); held.remove(token)
        }
        registrations = registrations.filter { desired.values.contains($0.key) }.merging(additions) { old, _ in old }
        actions = Dictionary(uniqueKeysWithValues: desired.compactMap { action, shortcut in registrations[shortcut].map { ($0, action) } })
    }
    public func resetPressedKeys() { held.removeAll() }
    public func receive(token: UInt32, pressed: Bool) {
        guard pressed else { held.remove(token); return }
        guard let action = actions[token], held.insert(token).inserted else { return }
        perform(action)
    }
}
