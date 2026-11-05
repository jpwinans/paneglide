import Foundation

/// Setup completion belongs to this Mac, not to exported window settings.
public final class SetupProgress {
    private let defaults: UserDefaults
    private let key = "setupCompleted"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func shouldPresent(accessibilityGranted: Bool, hasSavedSettings: Bool, shortcuts: ShortcutReadiness) -> Bool {
        if defaults.bool(forKey: key) { return false }
        if hasSavedSettings && canComplete(accessibilityGranted: accessibilityGranted, shortcuts: shortcuts) {
            complete(accessibilityGranted: true, shortcuts: shortcuts)
            return false
        }
        return true
    }

    public func canComplete(accessibilityGranted: Bool, shortcuts: ShortcutReadiness) -> Bool {
        accessibilityGranted && shortcuts != .unavailable
    }

    @discardableResult public func complete(accessibilityGranted: Bool, shortcuts: ShortcutReadiness) -> Bool {
        guard canComplete(accessibilityGranted: accessibilityGranted, shortcuts: shortcuts) else { return false }
        defaults.set(true, forKey: key)
        return true
    }
}
