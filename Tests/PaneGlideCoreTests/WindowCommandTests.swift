import Foundation
import CoreGraphics
import Testing
import PaneGlideCore

@MainActor final class TestWindowSystem: WindowSystem {
    var trusted = true
    var focused = "one"
    var windows = ["one": ManagedWindow(id: "one", frame: CGRect(x: 100, y: 100, width: 700, height: 500)), "two": ManagedWindow(id: "two", frame: CGRect(x: 400, y: 200, width: 600, height: 400))]
    var screens = [Display(id: "external", visibleFrame: CGRect(x: 0, y: 0, width: 2000, height: 1000))]
    var refuse = false
    var minimumSize: CGSize?
    func focusedWindow() throws -> ManagedWindow? { windows[focused] }
    func window(id: String) throws -> ManagedWindow { guard let result = windows[id] else { throw WindowError.unavailable }; return result }
    func displays() -> [Display] { screens }
    func apply(_ frame: CGRect, to id: String) throws -> ManagedWindow {
        guard !refuse else { throw WindowError.unavailable }
        var value = try window(id: id)
        let originalSize = value.frame.size
        value.frame = frame
        if !value.resizable { value.frame.size = originalSize }
        if let minimumSize { value.frame.size.width = max(frame.width, minimumSize.width); value.frame.size.height = max(frame.height, minimumSize.height) }
        windows[id] = value
        return value
    }
}

@Test @MainActor func commandsTargetCapturedWindowAndRestoreOriginal() throws {
    let system = TestWindowSystem()
    let engine = WindowCommands(system: system)
    let original = try system.window(id: "one").frame
    let untouched = try system.window(id: "two").frame
    system.focused = "two"
    let result = try engine.execute(.left, target: "one", settings: AppSettings())
    #expect(result.actual == CGRect(x: 0, y: 0, width: 1000, height: 1000))
    #expect(try system.window(id: "two").frame == untouched)
    _ = try engine.execute(.maximize, target: "one", settings: AppSettings())
    #expect(try engine.execute(.snapBack, target: "one", settings: AppSettings()).actual == original)
}

@Test @MainActor func savedThreeWindowLayoutsKeepIndependentBaselines() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("settings.json")
    let store = try SettingsStore(url: url)
    // Literal expected frames for several independently configured layouts.
    let cases: [(Double, Double, Double, PaneGlideCore.Dimension, PaneGlideCore.Dimension, CGRect, CGRect, CGRect)] = [
        (50, 100, 0.5, Dimension(25), Dimension(25), CGRect(x: 500, y: 0, width: 1000, height: 1000), CGRect(x: 0, y: 0, width: 500, height: 1000), CGRect(x: 1500, y: 0, width: 500, height: 1000)),
        (60, 80, 0.5, Dimension(20), Dimension(20), CGRect(x: 400, y: 100, width: 1200, height: 800), CGRect(x: 0, y: 0, width: 400, height: 1000), CGRect(x: 1600, y: 0, width: 400, height: 1000)),
        (40, 60, 0.5, Dimension(30), Dimension(30), CGRect(x: 600, y: 200, width: 800, height: 600), CGRect(x: 0, y: 0, width: 600, height: 1000), CGRect(x: 1400, y: 0, width: 600, height: 1000)),
        (50, 100, 0.6, Dimension(15), Dimension(400, .points), CGRect(x: 500, y: 0, width: 1000, height: 1000), CGRect(x: 0, y: 0, width: 300, height: 1000), CGRect(x: 1600, y: 0, width: 400, height: 1000))
    ]
    for (width, height, split, leftWidth, rightWidth, center, left, right) in cases {
        var value = AppSettings()
        value.layout.centerWidth = Dimension(width); value.layout.centerHeight = Dimension(height)
        value.layout.splitX = split
        value.layout.alternateLeft.enabled = true; value.layout.alternateLeft.width = leftWidth
        value.layout.alternateRight.enabled = true; value.layout.alternateRight.width = rightWidth
        try store.update(value)
        let settings = try SettingsStore(url: url).settings
        let system = TestWindowSystem()
        system.windows["three"] = ManagedWindow(id: "three", frame: CGRect(x: 300, y: 300, width: 500, height: 500))
        system.windows["untouched"] = ManagedWindow(id: "untouched", frame: CGRect(x: 50, y: 200, width: 800, height: 600))
        let before = system.windows
        let commands = WindowCommands(system: system)
        _ = try commands.execute(.center, target: "one", settings: settings)
        _ = try commands.execute(.left, target: "two", settings: settings)
        _ = try commands.execute(.left, target: "two", settings: settings)
        _ = try commands.execute(.right, target: "three", settings: settings)
        _ = try commands.execute(.right, target: "three", settings: settings)
        #expect(system.windows["one"]?.frame == center)
        #expect(system.windows["two"]?.frame == left)
        #expect(system.windows["three"]?.frame == right)
        #expect(system.windows["untouched"] == before["untouched"])
        for id in ["one", "two", "three"] {
            #expect(try commands.execute(.snapBack, target: id, settings: settings).actual == before[id]?.frame)
        }
        #expect(system.windows == before)
    }
}

@Test @MainActor func monitorTransferAndRestore() throws {
    let system = TestWindowSystem()
    system.screens.append(Display(id: "laptop", visibleFrame: CGRect(x: -1000, y: 0, width: 1000, height: 500)))
    system.windows["one"]!.frame = CGRect(x: 500, y: 100, width: 1000, height: 800)
    let engine = WindowCommands(system: system)
    #expect(try engine.execute(.nextMonitor, settings: AppSettings()).actual == CGRect(x: -750, y: 50, width: 500, height: 400))
    #expect(try engine.execute(.previousMonitor, settings: AppSettings()).actual == CGRect(x: 500, y: 100, width: 1000, height: 800))
    #expect(try engine.execute(.snapBack, settings: AppSettings()).actual == CGRect(x: 500, y: 100, width: 1000, height: 800))
    var settings = AppSettings(); settings.resizeProportionally = false
    system.windows["one"]!.frame = CGRect(x: 500, y: 100, width: 400, height: 200)
    #expect(try engine.execute(.nextMonitor, settings: settings).actual == CGRect(x: -750, y: 50, width: 400, height: 200))
}

@Test @MainActor func restoreWithOriginalDisplayMissing() throws {
    let system = TestWindowSystem()
    let engine = WindowCommands(system: system)
    _ = try engine.execute(.left, settings: AppSettings())
    system.screens = [Display(id: "laptop", visibleFrame: CGRect(x: -1000, y: 0, width: 1000, height: 500))]
    system.windows["one"]!.frame = CGRect(x: -1000, y: 0, width: 500, height: 500)
    #expect(try engine.execute(.snapBack, settings: AppSettings()).actual == CGRect(x: -700, y: 0, width: 700, height: 500))
}

@Test @MainActor func refusedFirstLayoutDoesNotCreateBaseline() throws {
    let system = TestWindowSystem()
    let commands = WindowCommands(system: system)
    system.refuse = true
    #expect(throws: WindowError.unavailable) { try commands.execute(.left, settings: AppSettings()) }
    system.refuse = false
    // A manual edit after a refused command must become the next sequence's
    // baseline, rather than restoring a frame from the unsuccessful request.
    let edited = CGRect(x: 320, y: 210, width: 640, height: 480)
    system.windows["one"]!.frame = edited
    _ = try commands.execute(.right, settings: AppSettings())
    #expect(try commands.execute(.snapBack, settings: AppSettings()).actual == edited)
}

@Test @MainActor func ambiguousDisplaysRemainUsableWithoutApplyingSavedProfiles() throws {
    let system = TestWindowSystem()
    system.screens = [
        Display(id: "session-1", visibleFrame: CGRect(x: 0, y: 0, width: 2000, height: 1000), supportsProfile: false),
        Display(id: "session-2", visibleFrame: CGRect(x: 2000, y: 0, width: 1000, height: 500), supportsProfile: false)
    ]
    var settings = AppSettings()
    settings.layout.splitX = 0.6
    var saved = LayoutSettings(); saved.splitX = 0.2
    settings.displayLayouts["session-1"] = saved
    settings.displayLayouts["session-2"] = saved
    let commands = WindowCommands(system: system)
    #expect(try commands.execute(.left, settings: settings).actual == CGRect(x: 0, y: 0, width: 1200, height: 1000))
    #expect(try commands.execute(.nextMonitor, settings: settings).actual == CGRect(x: 2000, y: 0, width: 600, height: 500))
    #expect(try commands.execute(.right, settings: settings).actual == CGRect(x: 2600, y: 0, width: 400, height: 500))
    // A later unambiguous snapshot may safely use its retained explicit profile.
    system.screens[1] = Display(id: "session-2", visibleFrame: CGRect(x: 2000, y: 0, width: 1000, height: 500))
    #expect(try commands.execute(.left, settings: settings).actual == CGRect(x: 2000, y: 0, width: 200, height: 500))
    #expect(settings.displayLayouts["session-2"] == saved)
}

@Test @MainActor func fixedSizeWindowIsCenteredWithinRequestedRegion() throws {
    let system = TestWindowSystem(); system.windows["one"]!.resizable = false
    let engine = WindowCommands(system: system)
    let result = try engine.execute(.left, settings: AppSettings())
    #expect(result.actual == CGRect(x: 150, y: 250, width: 700, height: 500))
    #expect(result.constrained)
}

@Test @MainActor func failedCommandsPreserveWindowsAndRestoreBaseline() throws {
    let system = TestWindowSystem(); let engine = WindowCommands(system: system)
    let original = try system.window(id: "one").frame
    system.trusted = false
    #expect(throws: WindowError.permissionRequired) { try engine.execute(.left, settings: AppSettings()) }
    #expect(try system.window(id: "one").frame == original)
    system.trusted = true
    _ = try engine.execute(.left, settings: AppSettings())
    system.refuse = true
    #expect(throws: WindowError.unavailable) { try engine.execute(.snapBack, settings: AppSettings()) }
    system.refuse = false
    #expect(try engine.execute(.snapBack, settings: AppSettings()).actual == original)
    system.windows["one"] = nil
    #expect(throws: WindowError.unavailable) { try engine.execute(.left, target: "one", settings: AppSettings()) }
    system.focused = "two"; system.windows["two"]!.fullScreen = true
    #expect(throws: WindowError.unsupported) { try engine.execute(.left, settings: AppSettings()) }
}

@Test @MainActor func fractionalBoundariesAlignToDisplayPixels() throws {
    let system = TestWindowSystem()
    system.screens = [Display(id: "retina", visibleFrame: CGRect(x: -1001, y: -101, width: 1001, height: 701), scale: 2)]
    system.windows["one"]!.frame = CGRect(x: -900, y: 0, width: 400, height: 300)
    var settings = AppSettings(); settings.layout.splitX = 0.333
    let engine = WindowCommands(system: system)
    #expect(try engine.execute(.left, settings: settings).requested == CGRect(x: -1001, y: -101, width: 333.5, height: 701))
    #expect(try engine.execute(.right, settings: settings).requested == CGRect(x: -667.5, y: -101, width: 667.5, height: 701))
    system.screens = [Display(id: "standard", visibleFrame: CGRect(x: -1001, y: -101, width: 1001, height: 701), scale: 1)]
    #expect(try engine.execute(.left, settings: settings).requested == CGRect(x: -1001, y: -101, width: 333, height: 701))
}
