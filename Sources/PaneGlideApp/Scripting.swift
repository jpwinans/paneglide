import AppKit
import PaneGlideCore

// Cocoa's "list of any" conversion calls scriptingAnyDescriptor on each item;
// a nested Swift array does not implement that Objective-C conversion hook.
private final class ScriptRectangle: NSObject {
    let coordinates: [Double]
    init(_ coordinates: [Double]) { self.coordinates = coordinates }
    @objc func scriptingAnyDescriptor() -> NSAppleEventDescriptor {
        let result = NSAppleEventDescriptor.list()
        for (index, coordinate) in coordinates.enumerated() {
            result.insert(NSAppleEventDescriptor(double: coordinate), at: index + 1)
        }
        return result
    }
}

// Cocoa dispatches scripting commands on the application's main run loop. The
// runtime assertion below enforces that contract before touching UI or command state.
@objc(SUCommand) final class SUCommand: NSScriptCommand, @unchecked Sendable {
    private enum ScriptResult: Sendable { case rectangle([Double]), batch([[Double]]) }
    override func performDefaultImplementation() -> Any? {
        let output = MainActor.assumeIsolated { () -> ScriptResult? in
            guard let controller = NSApp.delegate as? AppController else { return nil }
            do {
                let monitor = (evaluatedArguments?["monitor"] as? NSNumber)?.intValue
                let result: CommandResult
                switch commandDescription.commandName {
                case "tile windows", "cascade windows":
                    let allApps = (evaluatedArguments?["allApplications"] as? NSNumber)?.boolValue ?? false
                    let mode: BatchArrangement = commandDescription.commandName == "tile windows" ? .tile : .cascade
                    return .batch(try arrange(mode, controller: controller, monitor: monitor, allApplications: allApps))
                case "do action":
                    guard let name = directParameter as? String else { throw SettingsError.invalid("Choose an action from the PaneGlide scripting dictionary.") }
                    if let standard = WindowAction(rawValue: name) {
                        result = try controller.commands.execute(standard, onMonitor: monitor, settings: controller.store.settings)
                    } else {
                        result = try controller.commands.execute(try customAction(name), onMonitor: monitor, settings: controller.store.settings)
                    }
                case "send to monitor":
                    guard let index = (directParameter as? NSNumber)?.intValue else { throw SettingsError.invalid("Supply a one-based monitor index.") }
                    result = try controller.commands.execute(.nextMonitor, onMonitor: index, settings: controller.store.settings)
                case "move to", "resize to", "move and resize to", "fit to grid":
                    let name = commandDescription.commandName
                    let values = try numbers(directParameter, count: name == "move to" || name == "resize to" ? 2 : 4)
                    let geometry: CustomGeometry
                    switch name {
                    case "move to": geometry = .move(CGPoint(x: values[0], y: values[1]))
                    case "resize to": geometry = .resize(CGSize(width: values[0], height: values[1]))
                    case "move and resize to": geometry = .rectangle(CGRect(x: values[0], y: values[1], width: values[2], height: values[3]))
                    default:
                        let grid = try evaluatedArguments?["gridSize"].map { try numbers($0, count: 2) } ?? [6, 6]
                        guard grid.allSatisfy({ $0 > 0 && $0 <= 10000 && $0.rounded() == $0 }) else { throw SettingsError.invalid("Grid dimensions must be positive integers up to 10000.") }
                        geometry = .grid(CGRect(x: values[0], y: values[1], width: values[2], height: values[3]), columns: Int(grid[0]), rows: Int(grid[1]))
                    }
                    result = try controller.commands.execute(geometry, onMonitor: monitor, settings: controller.store.settings)
                case "show menu":
                    controller.statusItem?.button?.performClick(nil); return nil
                default: throw SettingsError.invalid("Unsupported scripting command.")
                }
                return .rectangle([result.actual.minX, result.actual.minY, result.actual.width, result.actual.height])
            } catch {
                scriptErrorNumber = -10000; scriptErrorString = error.localizedDescription
                return nil
            }
        }
        switch output { case .rectangle(let frame): return frame; case .batch(let frames): return frames.map(ScriptRectangle.init); case nil: return nil }
    }
    @MainActor private func arrange(_ mode: BatchArrangement, controller: AppController, monitor: Int?, allApplications: Bool) throws -> [[Double]] {
        let displays = controller.windows.displays()
        guard !displays.isEmpty else { throw WindowError.noDisplay }
        let target = try controller.windows.focusedWindow()
        let index: Int
        if let monitor {
            guard (1...displays.count).contains(monitor) else { throw SettingsError.invalid("Monitor index is out of range.") }
            index = monitor - 1
        } else {
            guard let target else { throw WindowError.noWindow }
            index = displays.indices.max { first, second in
                let a = displays[first].visibleFrame.intersection(target.frame); let b = displays[second].visibleFrame.intersection(target.frame)
                return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
            } ?? 0
        }
        let display = displays[index]
        let windows = try controller.windows.batchWindows(allApplications: allApplications).filter { display.visibleFrame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
        guard !windows.isEmpty else { throw WindowError.noWindow }
        let settings = controller.store.settings
        let area = PaneGlideCore.Layout.frame(for: .maximize, current: .zero, screen: display.visibleFrame, settings: settings.layout(for: display))
        let geometries = try mode.geometries(count: windows.count, area: area)
        var frames: [[Double]] = []; var failed = 0
        for (window, geometry) in zip(windows, geometries) {
            do {
                let result = try controller.commands.execute(geometry, target: window.id, onMonitor: index + 1, settings: settings)
                frames.append([result.actual.minX, result.actual.minY, result.actual.width, result.actual.height])
            } catch { failed += 1 }
        }
        if failed > 0 { throw SettingsError.invalid("Arranged \(frames.count) windows; \(failed) could not be arranged. Each changed window can be restored with SnapBack.") }
        return frames
    }
    private func numbers(_ value: Any?, count: Int) throws -> [Double] {
        // Cocoa delivers the dictionary's legacy point/rectangle types as native
        // QuickDraw bytes (vertical before horizontal), not an NSNumber array.
        if let data = value as? Data, [2, 4].contains(count), data.count == count * 2 {
            let fields = data.withUnsafeBytes { bytes in
                (0..<count).map { Double(bytes.loadUnaligned(fromByteOffset: $0 * 2, as: Int16.self)) }
            }
            return count == 2 ? [fields[1], fields[0]] : [fields[1], fields[0], fields[3], fields[2]]
        }
        guard let array = value as? [NSNumber], array.count == count, array.allSatisfy({ $0.doubleValue.isFinite }) else {
            throw SettingsError.invalid("Supply a list of \(count) finite numbers. Rectangles use {x, y, width, height}.")
        }
        return array.map(\.doubleValue)
    }
    private func customAction(_ name: String) throws -> CustomGeometry {
        switch name {
        case "moveLeft": .anchor(x: 0, y: nil)
        case "moveRight": .anchor(x: 1, y: nil)
        case "moveUp": .anchor(x: nil, y: 0)
        case "moveDown": .anchor(x: nil, y: 1)
        case "moveUpperLeft": .anchor(x: 0, y: 0)
        case "moveUpperRight": .anchor(x: 1, y: 0)
        case "moveLowerLeft": .anchor(x: 0, y: 1)
        case "moveLowerRight": .anchor(x: 1, y: 1)
        case "moveCenter": .anchor(x: 0.5, y: 0.5)
        case "thirdLeft": .grid(CGRect(x: 0, y: 0, width: 1, height: 1), columns: 3, rows: 1)
        case "thirdCenter": .grid(CGRect(x: 1, y: 0, width: 1, height: 1), columns: 3, rows: 1)
        case "thirdRight": .grid(CGRect(x: 2, y: 0, width: 1, height: 1), columns: 3, rows: 1)
        case "thirdUpper": .grid(CGRect(x: 0, y: 0, width: 1, height: 1), columns: 1, rows: 3)
        case "thirdMiddle": .grid(CGRect(x: 0, y: 1, width: 1, height: 1), columns: 1, rows: 3)
        case "thirdLower": .grid(CGRect(x: 0, y: 2, width: 1, height: 1), columns: 1, rows: 3)
        default: throw SettingsError.invalid("Unknown action: \(name)")
        }
    }
}

extension NSApplication {
    @objc var paneGlideName: String { "PaneGlide" }
    @objc var paneGlideVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown" }
    @objc var paneGlideEnabled: Bool {
        get { (delegate as? AppController)?.store.settings.shortcutsEnabled ?? false }
        set {
            guard let controller = delegate as? AppController else { return }
            var value = controller.store.settings; value.shortcutsEnabled = newValue
            do { try controller.saveSettings(value) }
            catch { NSScriptCommand.current()?.scriptErrorNumber = -10000; NSScriptCommand.current()?.scriptErrorString = error.localizedDescription }
        }
    }
}
