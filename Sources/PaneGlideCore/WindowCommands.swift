import Foundation
import CoreGraphics

public struct Display: Equatable, Sendable {
    public let id: String
    public let name: String
    public let visibleFrame: CGRect
    public let scale: Double
    /// False when the hardware identity is missing or shared by multiple displays.
    public let supportsProfile: Bool
    public init(id: String, name: String = "Display", visibleFrame: CGRect, scale: Double = 1, supportsProfile: Bool = true) {
        self.id = id; self.name = name; self.visibleFrame = visibleFrame; self.scale = scale; self.supportsProfile = supportsProfile
    }
}
public struct ManagedWindow: Equatable, Sendable {
    public let id: String
    public var frame: CGRect
    public var movable = true
    public var resizable = true
    public var fullScreen = false
    public var minimized = false
    public init(id: String, frame: CGRect) { self.id = id; self.frame = frame }
}
public enum WindowError: Error, LocalizedError, Equatable {
    case permissionRequired, noWindow, unavailable, unsupported, noDisplay
    public var errorDescription: String? {
        switch self {
        case .permissionRequired: "Enable PaneGlide in System Settings → Privacy & Security → Accessibility, then retry."
        case .noWindow: "No movable application window is focused."
        case .unavailable: "The target window is no longer available or did not respond."
        case .unsupported: "This window cannot be positioned. Exit native full screen or select a normal window."
        case .noDisplay: "No usable display is available."
        }
    }
}
@MainActor public protocol WindowSystem {
    var trusted: Bool { get }
    func focusedWindow() throws -> ManagedWindow?
    func window(id: String) throws -> ManagedWindow
    func displays() -> [Display]
    func apply(_ frame: CGRect, to id: String) throws -> ManagedWindow
}
public struct CommandResult: Sendable {
    public let windowID: String
    public let previous: CGRect
    public let requested: CGRect
    public let actual: CGRect
    public let restored: Bool
    public var changed: Bool { !actual.approximatelyEquals(previous, tolerance: 0.01) }
    public var constrained: Bool { !actual.approximatelyEquals(requested) }
}
@MainActor public final class WindowCommands {
    private let system: any WindowSystem
    private struct Baseline { var frame: CGRect; var displayID: String }
    private var baselines: [String: Baseline] = [:]
    public init(system: any WindowSystem) { self.system = system }
    public func execute(_ geometry: CustomGeometry, target: String? = nil, onMonitor: Int? = nil, settings: AppSettings) throws -> CommandResult {
        try perform(.maximize, geometry: geometry, target: target, onMonitor: onMonitor, settings: settings)
    }
    public func execute(_ action: WindowAction, target: String? = nil, onMonitor: Int? = nil, settings: AppSettings) throws -> CommandResult {
        try perform(action, geometry: nil, target: target, onMonitor: onMonitor, settings: settings)
    }
    private func perform(_ action: WindowAction, geometry: CustomGeometry?, target: String?, onMonitor: Int?, settings: AppSettings) throws -> CommandResult {
        guard system.trusted else { throw WindowError.permissionRequired }
        let window = try target.map { try system.window(id: $0) } ?? system.focusedWindow()
        guard let window else { throw WindowError.noWindow }
        guard window.movable, !window.fullScreen, !window.minimized else { throw WindowError.unsupported }
        let displays = system.displays()
        guard let display = displays.max(by: { intersectionArea($0.visibleFrame, window.frame) < intersectionArea($1.visibleFrame, window.frame) }) else { throw WindowError.noDisplay }
        if let onMonitor, !(1...displays.count).contains(onMonitor) { throw SettingsError.invalid("Monitor index is out of range; indexes start at one.") }
        let layoutDisplay = onMonitor.map { displays[$0 - 1] } ?? display
        let layout = settings.layout(for: layoutDisplay)
        try layout.validate(screen: layoutDisplay.visibleFrame)
        var requested: CGRect
        if let geometry {
            let current = window.frame.offsetBy(dx: layoutDisplay.visibleFrame.minX - display.visibleFrame.minX, dy: layoutDisplay.visibleFrame.minY - display.visibleFrame.minY)
            let frame = try geometry.frame(current: current, screen: layoutDisplay.visibleFrame, settings: layout)
            requested = settings.keepInBounds ? frame.fitting(in: layoutDisplay.visibleFrame, resize: window.resizable) : frame
        } else if action == .snapBack {
            guard let baseline = baselines[window.id] else { return CommandResult(windowID: window.id, previous: window.frame, requested: window.frame, actual: window.frame, restored: false) }
            if displays.contains(where: { $0.id == baseline.displayID }) {
                requested = baseline.frame
            } else {
                requested = baseline.frame.fitting(in: display.visibleFrame, resize: window.resizable)
            }
        } else if action == .nextMonitor || action == .previousMonitor {
            guard let index = displays.firstIndex(where: { $0.id == display.id }), displays.count > 1 || onMonitor != nil else {
                return CommandResult(windowID: window.id, previous: window.frame, requested: window.frame, actual: window.frame, restored: false)
            }
            let offset = action == .nextMonitor ? 1 : displays.count - 1
            let destination = onMonitor.map { displays[$0 - 1] } ?? displays[(index + offset) % displays.count]
            let destinationSettings = settings.layout(for: destination)
            try destinationSettings.validate(screen: destination.visibleFrame)
            let sourceArea = Layout.frame(for: .maximize, current: window.frame, screen: display.visibleFrame, settings: settings.layout(for: display))
            let destinationArea = Layout.frame(for: .maximize, current: window.frame, screen: destination.visibleFrame, settings: destinationSettings)
            let sx = destinationArea.width / sourceArea.width
            let sy = destinationArea.height / sourceArea.height
            let mapped = CGRect(x: destinationArea.minX + (window.frame.minX - sourceArea.minX) * sx,
                y: destinationArea.minY + (window.frame.minY - sourceArea.minY) * sy,
                width: window.frame.width * (settings.resizeProportionally ? sx : 1),
                height: window.frame.height * (settings.resizeProportionally ? sy : 1))
            requested = settings.keepInBounds ? mapped.fitting(in: destinationArea, resize: window.resizable) : mapped
        } else {
            requested = Layout.frame(for: action, current: window.frame, screen: layoutDisplay.visibleFrame, settings: layout)
        }
        if action != .snapBack || geometry != nil {
            let scale = displays.max(by: { intersectionArea($0.visibleFrame, requested) < intersectionArea($1.visibleFrame, requested) })?.scale ?? 1
            requested = requested.alignedToPixels(scale: scale)
        }
        guard requested.width > 0, requested.height > 0 else { throw SettingsError.invalid("The requested layout leaves no room for the window.") }
        var result: ManagedWindow
        do {
            result = try system.apply(requested, to: window.id)
            var adjusted = result.frame
            if settings.centerConstrainedWindows && (abs(result.frame.width - requested.width) > 2 || abs(result.frame.height - requested.height) > 2) {
                adjusted.origin = CGPoint(x: requested.midX - result.frame.width / 2, y: requested.midY - result.frame.height / 2)
            }
            if settings.keepInBounds, let actualDisplay = displays.max(by: { intersectionArea($0.visibleFrame, requested) < intersectionArea($1.visibleFrame, requested) }) {
                adjusted = adjusted.fitting(in: actualDisplay.visibleFrame, resize: false)
            }
            if !adjusted.approximatelyEquals(result.frame) { result = try system.apply(adjusted, to: window.id) }
        } catch {
            if action != .snapBack, baselines[window.id] == nil,
               let actual = try? system.window(id: window.id), !actual.frame.approximatelyEquals(window.frame) {
                baselines[window.id] = Baseline(frame: window.frame, displayID: display.id)
            }
            throw error
        }
        if action == .snapBack {
            if result.frame.approximatelyEquals(requested) { baselines.removeValue(forKey: window.id) }
        } else if baselines[window.id] == nil && !result.frame.approximatelyEquals(window.frame, tolerance: 0.01) {
            baselines[window.id] = Baseline(frame: window.frame, displayID: display.id)
        }
        return CommandResult(windowID: window.id, previous: window.frame, requested: requested, actual: result.frame, restored: action == .snapBack && result.frame.approximatelyEquals(requested))
    }
}

private func intersectionArea(_ first: CGRect, _ second: CGRect) -> Double {
    let intersection = first.intersection(second)
    return intersection.isNull ? 0 : intersection.width * intersection.height
}

public extension CGRect {
    func alignedToPixels(scale: Double) -> CGRect {
        let scale = scale.isFinite && scale > 0 ? scale : 1
        let left = (minX * scale).rounded() / scale
        let top = (minY * scale).rounded() / scale
        let right = (maxX * scale).rounded() / scale
        let bottom = (maxY * scale).rounded() / scale
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
    func fitting(in area: CGRect, resize: Bool) -> CGRect {
        let w = resize ? min(width, area.width) : width
        let h = resize ? min(height, area.height) : height
        return CGRect(x: min(max(minX, area.minX), max(area.minX, area.maxX - w)),
                      y: min(max(minY, area.minY), max(area.minY, area.maxY - h)), width: w, height: h)
    }
}
