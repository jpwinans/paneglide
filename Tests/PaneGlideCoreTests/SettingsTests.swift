import Foundation
import CoreGraphics
import Testing
import PaneGlideCore

@Test func settingsMoveToNewLocationWithoutLosingLayoutsOrOriginalFile() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let originalURL = directory.appendingPathComponent("Previous/settings.json")
    let destination = directory.appendingPathComponent("PaneGlide/settings.json")
    let original = try SettingsStore(url: originalURL)
    var settings = AppSettings()
    settings.layout.centerWidth = Dimension(62)
    settings.layout.alternateLeft.enabled = true
    settings.layout.alternateLeft.width = Dimension(19)
    settings.displayLayouts["external"] = settings.layout
    settings.shortcuts = [.left: Shortcut(0, modifiers: 5)]
    try original.update(settings)
    let saved = try Data(contentsOf: originalURL)

    let migrated = try SettingsStore(url: destination, legacyURL: originalURL)

    #expect(migrated.settings == settings)
    #expect(migrated.recoveryNotice == nil)
    #expect(try Data(contentsOf: destination) == saved)
    #expect(try Data(contentsOf: originalURL) == saved)

    var changed = migrated.settings
    changed.layout.centerWidth = Dimension(58)
    try migrated.update(changed)
    #expect(try SettingsStore(url: destination, legacyURL: originalURL).settings == changed)
    #expect(try Data(contentsOf: originalURL) == saved)
}

@Test func settingsRejectInvalidGeometry() {
    var s = LayoutSettings()
    s.splitX = 1
    #expect(throws: SettingsError.self) { try s.validate() }
    s = LayoutSettings(); s.horizontalGap = -1
    #expect(throws: SettingsError.self) { try s.validate() }
    s = LayoutSettings(); s.centerWidth = Dimension(.infinity)
    #expect(throws: SettingsError.self) { try s.validate() }
    s = LayoutSettings(); s.alternateRight.width = Dimension(101)
    #expect(throws: SettingsError.self) { try s.validate() }
    s = LayoutSettings(); s.margins.left = 2000
    #expect(throws: SettingsError.self) { try s.validate(screen: CGRect(x: 0, y: 0, width: 2000, height: 1000)) }
    s = LayoutSettings(); s.alternateLeft.enabled = true; s.alternateLeft.fitBesideCenter = true; s.centerResize = false
    #expect(throws: SettingsError.self) { try s.validate() }
}

@Test func settingsPersistAndImportAtomically() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("settings.json")
    let store = try SettingsStore(url: url)
    var value = store.settings
    value.layout.centerWidth = Dimension(60)
    value.layout.centerHeight = Dimension(70)
    var laptop = LayoutSettings(); laptop.alternateLeft.enabled = true; laptop.alternateLeft.width = Dimension(40)
    value.displayLayouts["laptop"] = laptop
    value.menuVisible = false
    try store.update(value)
    let reopened = try SettingsStore(url: url)
    #expect(reopened.settings == value)
    #expect(reopened.settings.layout(for: "unknown").centerWidth.value == 60)
    #expect(reopened.settings.layout(for: "laptop").alternateLeft.width.value == 40)
    let exported = try store.exportData()
    try reopened.update(AppSettings())
    try reopened.importData(exported)
    #expect(reopened.settings == value)
    #expect(throws: (any Error).self) { try reopened.importData(Data("broken".utf8)) }
    #expect(reopened.settings == value)
    var invalid = value; invalid.layout.splitY = 0
    #expect(throws: SettingsError.self) { try reopened.update(invalid) }
    #expect(try SettingsStore(url: url).settings == value)
}

@Test func corruptSettingsArePreservedBeforeRecovery() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("settings.json")
    let bad = Data("{truncated".utf8)
    try bad.write(to: url)
    let store = try SettingsStore(url: url)
    #expect(store.recoveryNotice != nil)
    #expect(store.settings == AppSettings())
    try store.update(AppSettings())
    let backups = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("settings-recovery-") }
    #expect(backups.count == 1)
    #expect(try Data(contentsOf: #require(backups.first)) == bad)
}

@Test func allPreferenceFlagsSurviveRelaunch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("settings.json")
    let store = try SettingsStore(url: url)
    var value = AppSettings()
    value.hiddenActions = [.left, .center]
    value.shortcutsEnabled = false
    value.shortcuts = [.right: Shortcut(0, modifiers: 5)]
    value.menuVisible = false; value.showPreferencesOnLaunch = true
    value.showTooltips = false; value.showOverlay = false
    value.resizeProportionally = false; value.centerConstrainedWindows = false
    value.keepInBounds = false
    value.layout.splitX = 0.6; value.layout.splitY = 0.4
    value.layout.quarterX = 0.3; value.layout.quarterY = 0.7
    value.layout.margins.enabled = false; value.layout.margins.left = 10
    value.layout.gapsEnabled = false; value.layout.horizontalGap = 20
    value.layout.centerResize = false
    value.layout.centerWidth = Dimension(900, .points)
    value.layout.centerHeight = Dimension(80)
    value.layout.alternateLeft.enabled = true
    value.layout.alternateLeft.width = Dimension(350, .points)
    value.layout.alternateRight.enabled = true
    value.layout.alternateRight.width = Dimension(30)
    value.layout.linkAlternateWidths = true
    value.displayLayouts["disconnected"] = value.layout
    try store.update(value)
    let loaded = try SettingsStore(url: url).settings
    #expect(loaded == value)
    #expect(loaded.showPreferencesOnLaunch)
    #expect(loaded.hiddenActions == [.left, .center])
}

@Test func partialFutureAndInvalidSettingsRemainRecoverable() throws {
    var future = AppSettings(); future.version = 99; future.layout.splitX = 0.7
    var invalid = AppSettings(); invalid.layout.splitX = 1
    let documents = [Data("{\"version\":1,\"layout\":{\"splitX\":0.7}}".utf8),
                     try JSONEncoder().encode(future), try JSONEncoder().encode(invalid)]
    for document in documents {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("settings.json")
        try document.write(to: url)
        let recovered = try SettingsStore(url: url)
        #expect(recovered.settings == AppSettings())
        #expect(recovered.recoveryNotice != nil)
        #expect(try Data(contentsOf: url) == document)
        try recovered.update(AppSettings())
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("settings-recovery-") }
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == document)
        #expect(try SettingsStore(url: url).settings == AppSettings())
    }
}

@Test func failedDiskWritePreservesSavedAndInMemorySettings() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = directory.appendingPathComponent("settings.json")
    let store = try SettingsStore(url: url)
    try store.update(AppSettings())
    let original = try Data(contentsOf: url)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
    var changed = store.settings; changed.layout.splitX = 0.7
    #expect(throws: (any Error).self) { try store.update(changed) }
    #expect(store.settings == AppSettings())
    #expect(try Data(contentsOf: url) == original)
}

@Test func retiredOptionsDoNotInvalidateSavedLayouts() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("settings.json")
    var expected = AppSettings()
    expected.layout.centerWidth = Dimension(58)
    expected.layout.alternateLeft.enabled = true
    expected.layout.alternateLeft.width = Dimension(21)
    expected.displayLayouts["external"] = expected.layout
    expected.shortcuts = [.left: Shortcut(0, modifiers: 5)]
    let retiredOptions = ["automaticUpdateChecks", "accountForDrawers"]
    var document = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
    for key in retiredOptions { document[key] = true }
    let legacyData = try JSONSerialization.data(withJSONObject: document)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try legacyData.write(to: url)

    let store = try SettingsStore(url: url)
    #expect(store.recoveryNotice == nil)
    #expect(store.settings.layout == expected.layout)
    #expect(store.settings.displayLayouts == expected.displayLayouts)
    #expect(store.settings.shortcuts == expected.shortcuts)
    try store.importData(legacyData)
    let exported = try #require(JSONSerialization.jsonObject(with: store.exportData()) as? [String: Any])
    for key in retiredOptions { #expect(exported[key] == nil) }
    #expect(try SettingsStore(url: url).settings.layout == expected.layout)
}
