import Foundation
import Testing
import PaneGlideCore

@Test func releaseSelectionUsesPublishedVersionsAndExpectedPackage() throws {
    let data = Data(#"[{"tag_name":"v0.1.0","draft":false,"prerelease":false,"assets":[{"id":1,"name":"PaneGlide.zip","size":100}]},{"tag_name":"v0.10.0","draft":false,"prerelease":false,"assets":[{"id":2,"name":"PaneGlide.zip","size":200}]},{"tag_name":"v9.0.0","draft":false,"prerelease":true,"assets":[{"id":3,"name":"PaneGlide.zip","size":200}]}]"#.utf8)
    #expect(try ReleaseCatalog.update(in: data, current: ReleaseVersion("0.2.0")) == Release(version: ReleaseVersion("0.10.0"), assetID: 2, byteCount: 200))
    #expect(try ReleaseCatalog.update(in: data, current: ReleaseVersion("0.10.0")) == nil)
    #expect(throws: (any Error).self) { try ReleaseCatalog.update(in: Data("invalid".utf8), current: ReleaseVersion("0.1.0")) }
    #expect(throws: SettingsError.self) { try ReleaseVersion("1.2.3/../bad") }
}

private struct FixtureVerifier: ApplicationVerifier {
    func version(of application: URL, matching installed: URL) throws -> ReleaseVersion {
        let text = try String(contentsOf: application.appendingPathComponent("signed-version"), encoding: .utf8)
        guard text.hasPrefix("signed:") else { throw SettingsError.invalid("Invalid signature") }
        return try ReleaseVersion(String(text.dropFirst(7)))
    }
}
@Test func installerVerifiesAndAtomicallyRetainsPreviousBuild() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path); try? FileManager.default.removeItem(at: directory) }
    func app(_ name: String, version: String) throws -> URL {
        let path = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        try Data(version.utf8).write(to: path.appendingPathComponent("signed-version"))
        return path
    }
    let installed = try app("Installed.app", version: "signed:0.1.0")
    let candidate = try app("Update.app", version: "signed:0.2.0")
    let installer = ApplicationInstaller(installed: installed, verifier: FixtureVerifier())
    let backup = try installer.install(candidate)
    #expect(try String(contentsOf: installed.appendingPathComponent("signed-version"), encoding: .utf8) == "signed:0.2.0")
    #expect(try String(contentsOf: backup.appendingPathComponent("signed-version"), encoding: .utf8) == "signed:0.1.0")
    #expect(throws: SettingsError.self) { try installer.install(candidate) }
    try Data("tampered".utf8).write(to: candidate.appendingPathComponent("signed-version"))
    #expect(throws: SettingsError.self) { try installer.install(candidate) }
    #expect(try String(contentsOf: installed.appendingPathComponent("signed-version"), encoding: .utf8) == "signed:0.2.0")
    try Data("signed:0.3.0".utf8).write(to: candidate.appendingPathComponent("signed-version"))
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    #expect(throws: (any Error).self) { try installer.install(candidate) }
    #expect(try String(contentsOf: installed.appendingPathComponent("signed-version"), encoding: .utf8) == "signed:0.2.0")
}

private struct OfflineReleases: ReleaseSource {
    func releases() async throws -> Data { throw URLError(.notConnectedToInternet) }
}
@Test func offlineIsAnErrorRatherThanFalseUpToDate() async throws {
    let checker = UpdateChecker(source: OfflineReleases(), current: try ReleaseVersion("0.1.0"))
    await #expect(throws: URLError.self) { try await checker.check() }
}
