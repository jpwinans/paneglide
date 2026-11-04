public enum LoginState: String, Sendable { case enabled, disabled, requiresApproval, unavailable }
@MainActor public protocol LoginSystem {
    var state: LoginState { get }
    func enable() throws
    func disable() throws
}
@MainActor public final class LoginItem {
    private let system: any LoginSystem
    public var state: LoginState { system.state }
    public init(system: any LoginSystem) { self.system = system }
    public func setEnabled(_ enabled: Bool) throws {
        if enabled { try system.enable() } else { try system.disable() }
    }
}
