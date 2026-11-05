import Foundation
import Testing
import PaneGlideCore

@Test func setupRequiresAccessAndRemembersCompletionAcrossLaunches() throws {
    let suite = "PaneGlideSetupTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let setup = SetupProgress(defaults: defaults)
    #expect(setup.shouldPresent(accessibilityGranted: false, hasSavedSettings: false, shortcuts: .ready))
    #expect(!setup.complete(accessibilityGranted: false, shortcuts: .ready))
    #expect(SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: true, hasSavedSettings: false, shortcuts: .ready))
    #expect(setup.complete(accessibilityGranted: true, shortcuts: .ready))
    #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: true, hasSavedSettings: false, shortcuts: .ready))
    // Revocation is handled by Access status and Quick Start, without forcing a tour on every launch.
    #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: false, hasSavedSettings: false, shortcuts: .ready))
}

@Test func configuredUsersSkipSetupOnlyWhenAccessIsAlreadyGranted() throws {
    let suite = "PaneGlideSetupTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let setup = SetupProgress(defaults: defaults)
    #expect(setup.shouldPresent(accessibilityGranted: false, hasSavedSettings: true, shortcuts: .ready))
    #expect(!setup.shouldPresent(accessibilityGranted: true, hasSavedSettings: true, shortcuts: .ready))
    #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: false, hasSavedSettings: true, shortcuts: .ready))
}

@Test func setupBlocksFailedShortcutsButAllowsIntentionalMenuUse() throws {
    for readiness in [ShortcutReadiness.ready, .disabled, .unassigned] {
        let suite = "PaneGlideSetupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let setup = SetupProgress(defaults: defaults)
        #expect(setup.shouldPresent(accessibilityGranted: true, hasSavedSettings: true, shortcuts: .unavailable))
        #expect(!setup.complete(accessibilityGranted: true, shortcuts: .unavailable))
        #expect(!setup.canComplete(accessibilityGranted: false, shortcuts: readiness))
        #expect(setup.canComplete(accessibilityGranted: true, shortcuts: readiness))
        #expect(setup.complete(accessibilityGranted: true, shortcuts: readiness))
        #expect(!SetupProgress(defaults: defaults).shouldPresent(accessibilityGranted: true, hasSavedSettings: false, shortcuts: readiness))
    }
}
