#if DEBUG
import AppKit
import PaneGlideCore

extension AppController {
    /// Native acceptance is deliberately restricted to the disposable fixture.
    func runWorkflowTest() {
        var report: [String: Any] = ["trusted": windows.trusted, "timestamp": Date().description]
        var cases: [[String: Any]] = []
        func require(_ value: Bool, _ message: String) throws {
            if !value { throw SettingsError.invalid(message) }
        }
        func values(_ frame: CGRect) -> [Double] { [frame.minX, frame.minY, frame.width, frame.height] }
        do {
            guard let fixture = NSRunningApplication.runningApplications(withBundleIdentifier: "com.jpwinans.size-up.fixture").first else { throw WindowError.noWindow }
            func fixtureWindows() throws -> [ManagedWindow] {
                try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier, "The disposable fixture must be frontmost.")
                return try windows.batchWindows(allApplications: false)
            }
            let targets = try fixtureWindows().sorted { $0.frame.minX < $1.frame.minX }
            try require(targets.count == 4, "Launch the disposable fixture with --multiple.")
            let screens = windows.displays()
            guard let area = screens.first?.visibleFrame else { throw WindowError.unavailable }
            try require(area.width >= 1000 && area.height >= 600, "The fixture needs a primary usable desktop of at least 1000 × 600 logical points.")
            defer { for target in targets { _ = try? windows.apply(target.frame, to: target.id) } }
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("paneglide-workflow-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: temporary) }
            let url = temporary.appendingPathComponent("settings.json")
            let saved = try SettingsStore(url: url)
            // Expected normalized rectangles are independent of the layout engine.
            func relative(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
                CGRect(x: area.minX + x * area.width, y: area.minY + y * area.height,
                       width: width * area.width, height: height * area.height)
            }
            let scenarios: [(String, Double, Double, Double, PaneGlideCore.Dimension, PaneGlideCore.Dimension, [CGRect])] = [
                ("50-center-25-sides", 50, 100, 0.5, Dimension(25), Dimension(25), [relative(0.25,0,0.5,1), relative(0,0,0.25,1), relative(0.75,0,0.25,1)]),
                ("60x80-center-20-sides", 60, 80, 0.5, Dimension(20), Dimension(20), [relative(0.2,0.1,0.6,0.8), relative(0,0,0.2,1), relative(0.8,0,0.2,1)]),
                ("40x60-center-30-sides", 40, 60, 0.5, Dimension(30), Dimension(30), [relative(0.3,0.2,0.4,0.6), relative(0,0,0.3,1), relative(0.7,0,0.3,1)]),
                ("independent-60-split-15-percent-400-points", 50, 100, 0.6, Dimension(15), Dimension(400, .points), [relative(0.25,0,0.5,1), relative(0,0,0.15,1), CGRect(x:area.maxX-400,y:area.minY,width:400,height:area.height)])
            ]
            func arrange(_ name: String, settings: AppSettings, expected: [CGRect]) throws {
                try saved.update(settings)
                let loaded = try SettingsStore(url: url).settings
                _ = try commands.execute(.center, target: targets[0].id, settings: loaded)
                for (index, action) in [(1, WindowAction.left), (2, WindowAction.right)] {
                    _ = try commands.execute(action, target: targets[index].id, settings: loaded)
                    _ = try commands.execute(action, target: targets[index].id, settings: loaded)
                }
                let actual = try targets.prefix(3).map { try windows.window(id: $0.id).frame }
                try require(zip(actual, expected).allSatisfy { $0.approximatelyEquals($1, tolerance: 1) }, "Incorrect three-window layout: \(name)")
                try require(try windows.window(id: targets[3].id).frame == targets[3].frame, "An unrelated fixture window moved.")
                for target in targets.prefix(3) {
                    let restored = try commands.execute(.snapBack, target: target.id, settings: loaded)
                    try require(restored.actual.approximatelyEquals(target.frame, tolerance: 1), "A window lost its independent SnapBack baseline.")
                }
                cases.append(["case": name, "actual": actual.map(values), "expected": expected.map(values), "independentRestoration": true, "fourthUntouched": true])
            }
            for (name, width, height, split, left, right, expected) in scenarios {
                var settings = AppSettings()
                settings.layout.centerWidth = Dimension(width); settings.layout.centerHeight = Dimension(height)
                settings.layout.splitX = split
                settings.layout.alternateLeft.enabled = true; settings.layout.alternateLeft.width = left
                settings.layout.alternateRight.enabled = true; settings.layout.alternateRight.width = right
                try arrange(name, settings: settings, expected: expected)
            }
            var fit = AppSettings()
            fit.layout.margins.left = 20; fit.layout.margins.top = 10; fit.layout.margins.right = 40; fit.layout.margins.bottom = 30
            fit.layout.horizontalGap = 20; fit.layout.verticalGap = 10
            fit.layout.alternateLeft.enabled = true; fit.layout.alternateLeft.fitBesideCenter = true
            fit.layout.alternateRight.enabled = true; fit.layout.alternateRight.fitBesideCenter = true
            let inset = CGRect(x: area.minX + 20, y: area.minY + 10, width: area.width - 60, height: area.height - 40)
            try arrange("fit-center-with-margins-and-gaps", settings: fit, expected: [
                CGRect(x: inset.minX + inset.width * 0.25, y: inset.minY, width: inset.width * 0.5, height: inset.height),
                CGRect(x: inset.minX, y: inset.minY, width: inset.width * 0.25 - 20, height: inset.height),
                CGRect(x: inset.minX + inset.width * 0.75 + 20, y: inset.minY, width: inset.width * 0.25 - 20, height: inset.height)
            ])

            func fixtureCommand(_ command: String) throws {
                DistributedNotificationCenter.default().postNotificationName(.init("com.jpwinans.size-up.fixture.workflow"), object: command, userInfo: nil, deliverImmediately: true)
                let deadline = Date().addingTimeInterval(2)
                while Date() < deadline {
                    let data = try Data(contentsOf: URL(fileURLWithPath: "/private/tmp/paneglide-fixture.json"))
                    let state = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if state?["lastCommand"] as? String == command { return }
                    Thread.sleep(forTimeInterval: 0.025)
                }
                throw SettingsError.invalid("The fixture did not acknowledge \(command).")
            }
            _ = try commands.execute(.left, target: targets[0].id, settings: AppSettings())
            try fixtureCommand("rename")
            let renamed = try fixtureWindows()
            try require(renamed.contains { $0.id == targets[0].id }, "Title change changed the managed identity.")
            let restored = try commands.execute(.snapBack, target: targets[0].id, settings: AppSettings())
            try require(restored.actual == targets[0].frame, "Rename lost the baseline.")
            report["renameRestored"] = true

            _ = try commands.execute(.left, target: targets[1].id, settings: AppSettings())
            try fixtureCommand("replace")
            do {
                _ = try windows.window(id: targets[1].id)
                throw SettingsError.invalid("Closed window retained a usable identity.")
            } catch WindowError.unavailable { /* Expected: old AX identity is invalid. */ }
            // NSWindow creation is acknowledged before WindowServer necessarily
            // publishes its visible bounds. Wait for that external boundary.
            var refreshed = try fixtureWindows()
            let discoveryDeadline = Date().addingTimeInterval(2)
            while refreshed.count < 4 && Date() < discoveryDeadline {
                Thread.sleep(forTimeInterval: 0.025)
                refreshed = try fixtureWindows()
            }
            let oldIDs = Set(targets.map(\.id))
            guard let replacement = refreshed.first(where: { !oldIDs.contains($0.id) }) else { throw SettingsError.invalid("Replacement window reused an old identity.") }
            let unchanged = try commands.execute(.snapBack, target: replacement.id, settings: AppSettings())
            try require(unchanged.actual == replacement.frame, "New window inherited the closed window's baseline.")
            report["closedIdentityRejected"] = true; report["replacementUnaffected"] = true
            report["passed"] = true
        } catch { report["error"] = error.localizedDescription }
        report["cases"] = cases
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: "/private/tmp/paneglide-workflow-test.json"), options: .atomic)
        }
        NSApp.terminate(nil)
    }
}
#endif
