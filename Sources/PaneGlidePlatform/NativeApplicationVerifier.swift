import Foundation
import Security
import PaneGlideCore

public struct NativeApplicationVerifier: ApplicationVerifier {
    public init() {}
    public func version(of application: URL, matching installed: URL) throws -> ReleaseVersion {
        func code(_ url: URL) throws -> SecStaticCode {
            var code: SecStaticCode?
            guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { throw SettingsError.invalid("The selected application has no readable code signature.") }
            return code
        }
        let current = try code(installed)
        let candidate = try code(application)
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        var appleRequirement: SecRequirement?
        guard SecRequirementCreateWithString("anchor apple generic and identifier \"com.jpwinans.size-up\"" as CFString, [], &appleRequirement) == errSecSuccess,
              SecStaticCodeCheckValidity(current, flags, appleRequirement) == errSecSuccess else {
            throw SettingsError.invalid("Updates require a valid Apple-signed development or Developer ID build. Ad-hoc builds cannot establish a trusted update identity.")
        }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(current, [], &requirement) == errSecSuccess,
              SecStaticCodeCheckValidity(candidate, flags, requirement) == errSecSuccess else {
            throw SettingsError.invalid("Update rejected: the app is modified or does not match this installation's signing identity.")
        }
        let data = try Data(contentsOf: application.appendingPathComponent("Contents/Info.plist"))
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              info["CFBundleIdentifier"] as? String == "com.jpwinans.size-up",
              info["CFBundleExecutable"] as? String == "PaneGlide",
              let version = info["CFBundleShortVersionString"] as? String,
              let minimum = info["LSMinimumSystemVersion"] as? String else { throw SettingsError.invalid("The update has invalid application metadata.") }
        let minimumComponents = minimum.split(separator: ".", omittingEmptySubsequences: false)
        let minimumParts = minimumComponents.compactMap { Int($0) }
        guard minimumParts.count == minimumComponents.count, (1...3).contains(minimumParts.count), minimumParts.allSatisfy({ $0 >= 0 }), ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: minimumParts[0], minorVersion: minimumParts.count > 1 ? minimumParts[1] : 0, patchVersion: minimumParts.count > 2 ? minimumParts[2] : 0)) else { throw SettingsError.invalid("This update requires a newer version of macOS or has invalid minimum-version metadata.") }
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-verify_arch", "arm64", application.appendingPathComponent("Contents/MacOS/PaneGlide").path]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SettingsError.invalid("The update does not contain native Apple silicon code.") }
        return try ReleaseVersion(version)
    }
}
