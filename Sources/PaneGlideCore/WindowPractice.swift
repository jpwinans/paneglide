/// Optional, in-memory progress for the first window move and restore.
public struct WindowPractice: Sendable {
    public enum Step: Equatable, Sendable { case idle, moveLeft, restore, complete }
    public private(set) var step: Step = .idle
    private var windowID: String?
    public init() {}
    public mutating func begin() { step = .moveLeft; windowID = nil }
    public mutating func cancel() { step = .idle; windowID = nil }
    public mutating func receive(_ action: WindowAction, result: CommandResult) {
        if step == .moveLeft && action == .left && result.changed {
            windowID = result.windowID
            step = .restore
        } else if step == .restore && action == .snapBack && result.windowID == windowID && result.restored {
            step = .complete
            windowID = nil
        }
    }
}
