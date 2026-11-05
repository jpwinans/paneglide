import CoreGraphics
import Testing
import PaneGlideCore

@Test @MainActor func practiceConfirmsAMoveAndRestoreWithoutReplacingSnapBackHistory() throws {
    let system = TestWindowSystem()
    let commands = WindowCommands(system: system)
    var practice = WindowPractice()
    // An arrangement before the check must remain the SnapBack baseline.
    _ = try commands.execute(.center, settings: AppSettings())
    practice.begin()
    #expect(practice.step == .moveLeft)
    let moved = try commands.execute(.left, settings: AppSettings())
    practice.receive(.left, result: moved)
    #expect(moved.actual == CGRect(x: 0, y: 0, width: 1000, height: 1000))
    #expect(practice.step == .restore)
    let restored = try commands.execute(.snapBack, settings: AppSettings())
    practice.receive(.snapBack, result: restored)
    #expect(restored.actual == CGRect(x: 100, y: 100, width: 700, height: 500))
    #expect(practice.step == .complete)
}

@Test @MainActor func practiceRequiresAnActualMoveThenRestorationOfThatSameWindow() throws {
    let system = TestWindowSystem()
    let commands = WindowCommands(system: system)
    var practice = WindowPractice()
    // Already at Left is a no-op, not proof that window control worked.
    system.windows["one"]!.frame = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    practice.begin()
    practice.receive(.left, result: try commands.execute(.left, settings: AppSettings()))
    #expect(practice.step == .moveLeft)
    system.windows["one"]!.frame = CGRect(x: 100, y: 100, width: 700, height: 500)
    practice.receive(.left, result: try commands.execute(.left, settings: AppSettings()))
    #expect(practice.step == .restore)
    _ = try commands.execute(.right, target: "two", settings: AppSettings())
    practice.receive(.snapBack, result: try commands.execute(.snapBack, target: "two", settings: AppSettings()))
    #expect(practice.step == .restore)
    // An application can refuse the baseline size even though the command returns.
    system.minimumSize = CGSize(width: 900, height: 800)
    practice.receive(.snapBack, result: try commands.execute(.snapBack, settings: AppSettings()))
    #expect(practice.step == .restore)
    system.minimumSize = nil
    practice.receive(.snapBack, result: try commands.execute(.snapBack, settings: AppSettings()))
    #expect(practice.step == .complete)
}

@Test @MainActor func practiceIsOptInAndCancelPreservesWindowRestoration() throws {
    let system = TestWindowSystem()
    let commands = WindowCommands(system: system)
    var practice = WindowPractice()
    practice.receive(.left, result: try commands.execute(.left, settings: AppSettings()))
    #expect(practice.step == .idle)
    _ = try commands.execute(.snapBack, settings: AppSettings())
    practice.begin()
    practice.receive(.left, result: try commands.execute(.left, settings: AppSettings()))
    practice.cancel()
    let result = try commands.execute(.snapBack, settings: AppSettings())
    practice.receive(.snapBack, result: result)
    #expect(practice.step == .idle)
    #expect(result.actual == CGRect(x: 100, y: 100, width: 700, height: 500))
    practice.begin()
    practice.receive(.left, result: try commands.execute(.left, target: "two", settings: AppSettings()))
    practice.receive(.snapBack, result: try commands.execute(.snapBack, target: "two", settings: AppSettings()))
    #expect(practice.step == .complete)
}
