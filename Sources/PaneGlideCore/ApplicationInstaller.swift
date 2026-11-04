import Foundation
import Darwin

public protocol ApplicationVerifier: Sendable {
    func version(of application: URL, matching installed: URL) throws -> ReleaseVersion
}
public struct ApplicationInstaller: Sendable {
    public let installed: URL
    private let verifier: any ApplicationVerifier
    public init(installed: URL, verifier: any ApplicationVerifier) { self.installed = installed; self.verifier = verifier }
    /// Returns the retained previous application after a successful atomic swap.
    public func install(_ candidate: URL) throws -> URL {
        let current = try verifier.version(of: installed, matching: installed)
        let offered = try verifier.version(of: candidate, matching: installed)
        guard offered > current else { throw SettingsError.invalid("The selected app is not newer than the installed version.") }
        let stage = installed.deletingLastPathComponent().appendingPathComponent(".PaneGlide.previous-\(UUID().uuidString).app")
        var swapped = false
        defer { if !swapped { try? FileManager.default.removeItem(at: stage) } }
        try FileManager.default.copyItem(at: candidate, to: stage)
        guard try verifier.version(of: stage, matching: installed) == offered else { throw SettingsError.invalid("The staged update changed during copying.") }
        // Both paths are siblings on one volume. RENAME_SWAP leaves the existing
        // application untouched if it fails, and retains the old app at stage.
        guard renamex_np(stage.path, installed.path, UInt32(RENAME_SWAP)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        swapped = true
        return stage
    }
}
