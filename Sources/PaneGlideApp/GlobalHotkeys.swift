import AppKit
import Carbon
import PaneGlideCore

@MainActor final class GlobalHotkeys: HotkeySystem {
    var onEvent: ((UInt32, Bool) -> Void)?
    private var references: [UInt32: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var sequence: UInt32 = 0

    func start() throws {
        guard handler == nil else { return }
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let error = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<GlobalHotkeys>.fromOpaque(context).takeUnretainedValue()
                var identifier = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard result == noErr, identifier.signature == 0x53555a50 else { return OSStatus(eventNotHandledErr) }
                owner.onEvent?(identifier.id, GetEventKind(event) == UInt32(kEventHotKeyPressed))
                return noErr
            }
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard error == noErr else { throw SettingsError.invalid("Could not start global shortcuts (macOS error \(error)).") }
    }
    func register(_ shortcut: Shortcut) throws -> UInt32 {
        try start()
        sequence += 1
        var flags: UInt32 = 0
        if shortcut.modifiers & 1 != 0 { flags |= UInt32(cmdKey) }
        if shortcut.modifiers & 2 != 0 { flags |= UInt32(optionKey) }
        if shortcut.modifiers & 4 != 0 { flags |= UInt32(controlKey) }
        if shortcut.modifiers & 8 != 0 { flags |= UInt32(shiftKey) }
        var reference: EventHotKeyRef?
        let error = RegisterEventHotKey(shortcut.keyCode, flags, EventHotKeyID(signature: 0x53555a50, id: sequence), GetApplicationEventTarget(), 0, &reference)
        guard error == noErr, let reference else {
            throw SettingsError.invalid("Could not register \(shortcut.label). Another app or macOS may use it (error \(error)). Disable the conflicting shortcut and retry. Existing working bindings are retained.")
        }
        references[sequence] = reference
        return sequence
    }
    func unregister(_ token: UInt32) {
        if let reference = references.removeValue(forKey: token) { UnregisterEventHotKey(reference) }
    }
    func stop() {
        Array(references.keys).forEach(unregister)
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}

extension Shortcut {
    init(event: NSEvent) {
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { modifiers |= 1 }
        if event.modifierFlags.contains(.option) { modifiers |= 2 }
        if event.modifierFlags.contains(.control) { modifiers |= 4 }
        if event.modifierFlags.contains(.shift) { modifiers |= 8 }
        self.init(UInt32(event.keyCode), modifiers: modifiers)
    }
    var label: String {
        let symbols = (modifiers & 4 != 0 ? "⌃" : "") + (modifiers & 2 != 0 ? "⌥" : "") + (modifiers & 8 != 0 ? "⇧" : "") + (modifiers & 1 != 0 ? "⌘" : "")
        let special: [UInt32: String] = [123: "←", 124: "→", 125: "↓", 126: "↑", 36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape", 117: "⌦", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down"]
        if let key = special[keyCode] { return symbols + key }
        let functions: [UInt32: String] = [122:"F1", 120:"F2", 99:"F3", 118:"F4", 96:"F5", 97:"F6", 98:"F7", 100:"F8", 101:"F9", 109:"F10", 103:"F11", 111:"F12", 105:"F13", 107:"F14", 113:"F15", 106:"F16", 64:"F17", 79:"F18", 80:"F19", 90:"F20"]
        if let key = functions[keyCode] { return symbols + key }
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
            let layout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)
            var state: UInt32 = 0; var length = 0; var characters = [UniChar](repeating: 0, count: 8)
            let result = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &state, characters.count, &length, &characters)
            if result == noErr, length > 0 { return symbols + String(utf16CodeUnits: characters, count: length).uppercased() }
        }
        return symbols + "Key \(keyCode)"
    }
}
