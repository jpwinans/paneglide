import Foundation

@MainActor public protocol Cancellation { func cancel() }
@MainActor public protocol DelayScheduler {
    func after(_ seconds: TimeInterval, perform: @escaping @MainActor () -> Void) -> any Cancellation
}
@MainActor public protocol OverlaySurface { func show(_ message: String); func hide() }

@MainActor public final class ActionFeedback {
    private let surface: any OverlaySurface
    private let scheduler: any DelayScheduler
    private var pending: (any Cancellation)?
    private var generation = 0
    public init(surface: any OverlaySurface, scheduler: any DelayScheduler) { self.surface = surface; self.scheduler = scheduler }
    public func show(_ message: String, enabled: Bool = true, duration: TimeInterval = 1.2) {
        hide()
        guard enabled else { return }
        surface.show(message)
        let current = generation
        pending = scheduler.after(duration) { [weak self] in
            guard let self, self.generation == current else { return }
            self.hide()
        }
    }
    public func hide() { generation += 1; pending?.cancel(); pending = nil; surface.hide() }
}
