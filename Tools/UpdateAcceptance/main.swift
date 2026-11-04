import Foundation
import PaneGlideCore
import PaneGlidePlatform

let arguments = CommandLine.arguments
if arguments.count < 3 {
    fputs("Usage: UpdateAcceptance INSTALLED.app CANDIDATE.app [--install]\n", stderr)
    exit(2)
}
do {
    let installed = URL(fileURLWithPath: arguments[1])
    let candidate = URL(fileURLWithPath: arguments[2])
    let verifier = NativeApplicationVerifier()
    let before = try verifier.version(of: installed, matching: installed)
    let offered = try verifier.version(of: candidate, matching: installed)
    print("Verified native signed app: \(before) -> \(offered)")
    if arguments.contains("--install") {
        let backup = try ApplicationInstaller(installed: installed, verifier: verifier).install(candidate)
        let after = try verifier.version(of: installed, matching: installed)
        let previous = try verifier.version(of: backup, matching: installed)
        guard after == offered, previous == before else { throw SettingsError.invalid("Installed/backup versions differ from the verified versions.") }
        print("Installed \(after); retained signed backup \(previous)")
    }
} catch {
    fputs("Update rejected: \(error.localizedDescription)\n", stderr)
    exit(1)
}
