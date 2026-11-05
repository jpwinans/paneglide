import Foundation
import Testing
import PaneGlideCore

@Test func setupRequiresAccessAndRemembersCompletionAcrossLaunches() throws {
    let suite = "PaneGlideSetupTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let setup = SetupProgress(defaults: defaults)
    #expect(setup.shouldPresent(accessibilityGranted: false, hasSavedSettings: false))
    #expect(!setup.complete(accessibilityGranted: false))
    #expect(SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: true, hasSavedSettings: false))
    #expect(setup.complete(accessibilityGranted: true))
    #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: true, hasSavedSettings: false))
    // Revocation is handled by Access status and Quick Start, without forcing a tour on every launch.
    #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: false, hasSavedSettings: false))
}

@Test func configuredUsersSkipSetupOnlyWhenAccessIsAlreadyGranted() throws {
    let suite = "PaneGlideSetupTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let setup = SetupProgress(defaults: defaults)
    #expect(setup.shouldPresent(accessibilityGranted: false, hasSavedSettings: true))
    #expect(!setup.shouldPresent(accessibilityGranted: true, hasSavedSettings: true))
    #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: false, hasSavedSettings: true))
}
