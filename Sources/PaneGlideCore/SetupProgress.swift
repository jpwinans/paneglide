import Foundation

/// Setup completion belongs to this Mac, not to exported window settings.
public final class SetupProgress {
    private let defaults: UserDefaults
    private let key = "setupCompleted"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func shouldPresent(accessibilityGranted: Bool, hasSavedSettings: Bool) -> Bool {
        if defaults.bool(forKey: key) { return false }
        if hasSavedSettings && accessibilityGranted {
            complete(accessibilityGranted: true)
            return false
        }
        return true
    }

    @discardableResult public func complete(accessibilityGranted: Bool) -> Bool {
        guard accessibilityGranted else { return false }
        defaults.set(true, forKey: key)
        return true
    }
}
