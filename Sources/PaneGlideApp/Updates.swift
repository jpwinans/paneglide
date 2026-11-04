import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PaneGlideCore
import PaneGlidePlatform

@MainActor final class UpdateManager: ObservableObject {
    @Published var status = "Checks published PaneGlide releases on GitHub. No account or token is needed."
    @Published var available: Release?
    @Published var busy = false
    @Published var restartAvailable = false
    private var timer: Timer?
    private var automatic = false
    var onUpdateFound: (() -> Void)?
    func configure(automatic enabled: Bool) {
        guard enabled != automatic else { return }; automatic = enabled
        timer?.invalidate(); timer = nil
        if enabled {
            check()
            timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.check() } }
        }
    }
    func check() {
        guard !busy else { return }; busy = true; status = "Checking releases…"
        Task {
            defer { busy = false }
            do {
                let version = try ReleaseVersion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")
                available = try await UpdateChecker(source: GitHubReleases(), current: version).check()
                if let available { status = "Version \(available.version) is available. Download PaneGlide.zip from the release, unzip it, then choose Install Downloaded App."; onUpdateFound?() }
                else { status = "No newer published PaneGlide package is available." }
            } catch { status = error.localizedDescription }
        }
    }
    func openReleases() { NSWorkspace.shared.open(URL(string: "https://github.com/jpwinans/paneglide/releases")!) }
    func installDownloadedApp() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.application]; panel.allowsMultipleSelection = false
        panel.message = "Choose the extracted PaneGlide.app. Its signature and version will be verified before installation."
        guard panel.runModal() == .OK, let candidate = panel.url else { return }
        busy = true; status = "Verifying and installing…"
        let installed = Bundle.main.bundleURL
        Task {
            defer { busy = false }
            do {
                let backup = try await Task.detached(priority: .userInitiated) {
                    try ApplicationInstaller(installed: installed, verifier: NativeApplicationVerifier()).install(candidate)
                }.value
                status = "Update installed. Reopen PaneGlide to use it. Previous build retained at \(backup.path)."
                available = nil; restartAvailable = true
            } catch { status = "Installation failed; the existing app was retained. \(error.localizedDescription)" }
        }
    }
}

struct UpdatePreferences: View {
    @ObservedObject var updates: UpdateManager
    @Binding var automatic: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Check for updates automatically (daily)", isOn: $automatic)
            HStack {
                Button("Check for Updates Now", action: updates.check)
                Button("Open Releases…", action: updates.openReleases)
                Button("Install Downloaded App…", action: updates.installDownloadedApp)
            }.disabled(updates.busy)
            Text(updates.status).font(.callout).textSelection(.enabled)
            if updates.restartAvailable { Text("Quit PaneGlide and reopen it from Finder to finish. Your settings stay in Application Support.").foregroundStyle(.secondary) }
        }
    }
}
