import Foundation
import CoreGraphics

public enum SettingsError: Error, LocalizedError, Equatable {
    case invalid(String)
    public var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
public extension LayoutSettings {
    func validate(screen: CGRect? = nil) throws {
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw SettingsError.invalid(message) }
        }
        for divider in [splitX, splitY, quarterX, quarterY] {
            try require(divider.isFinite && divider > 0 && divider < 1, "Partition percentages must be between 0 and 100.")
        }
        for margin in [margins.left, margins.right, margins.top, margins.bottom, horizontalGap, verticalGap] {
            try require(margin.isFinite && margin >= 0, "Margins and gaps must be finite and nonnegative.")
        }
        for size in [centerWidth, centerHeight, alternateLeft.width, alternateRight.width] {
            try require(size.value.isFinite && size.value > 0 && (size.unit != .percent || size.value <= 100), "Sizes must be positive; percentages cannot exceed 100.")
        }
        let rightFit = linkAlternateWidths ? alternateLeft.fitBesideCenter : alternateRight.fitBesideCenter
        let fit = (alternateLeft.enabled && alternateLeft.fitBesideCenter) || (alternateRight.enabled && rightFit)
        try require(!fit || centerResize, "Fit beside Center requires Center resizing to be enabled.")
        if let screen {
            try require(screen.width.isFinite && screen.height.isFinite && screen.width > 0 && screen.height > 0, "The display has no usable area.")
            let width = screen.width - (margins.enabled ? margins.left + margins.right : 0)
            let height = screen.height - (margins.enabled ? margins.top + margins.bottom : 0)
            try require(width > 0 && height > 0, "Screen margins leave no usable area.")
            let gx = gapsEnabled ? horizontalGap : 0
            let gy = gapsEnabled ? verticalGap : 0
            try require(width * min(splitX, 1 - splitX, quarterX, 1 - quarterX) > gx / 2 && height * min(splitY, 1 - splitY, quarterY, 1 - quarterY) > gy / 2, "Gaps leave no room inside a partition.")
            try require(!fit || (width - centerWidth.resolve(width)) / 2 > gx, "The configured Center width and gaps leave no room for side windows.")
        }
    }
}
public struct AppSettings: Codable, Equatable, Sendable {
    public var version = 1
    public var layout = LayoutSettings()
    public var displayLayouts: [String: LayoutSettings] = [:]
    public var shortcutsEnabled = true
    private var shortcutBindings: [WindowAction: Shortcut]?
    public var shortcuts: [WindowAction: Shortcut] {
        get { shortcutBindings ?? Shortcut.defaults }
        set { shortcutBindings = newValue }
    }
    public var menuVisible = true
    public var showPreferencesOnLaunch = false
    public var resizeProportionally = true
    public var centerConstrainedWindows = true
    public var keepInBounds = true
    public var hiddenActions: Set<WindowAction> = []
    public init() {}
    public func layout(for displayID: String) -> LayoutSettings { displayLayouts[displayID] ?? layout }
    public func layout(for display: Display) -> LayoutSettings { display.supportsProfile ? layout(for: display.id) : layout }
    public func validate() throws {
        guard version == 1 else { throw SettingsError.invalid("Unsupported settings version: \(version)") }
        try Shortcut.validate(shortcuts)
        try layout.validate()
        for value in displayLayouts.values { try value.validate() }
    }
}

public final class SettingsStore {
    public private(set) var settings = AppSettings()
    public private(set) var recoveryNotice: String?
    public let url: URL
    public init(url: URL, legacyURL: URL? = nil) throws {
        self.url = url
        if !FileManager.default.fileExists(atPath: url.path),
           let legacyURL, FileManager.default.fileExists(atPath: legacyURL.path) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: legacyURL, to: url)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            do {
                let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
                try loaded.validate()
                settings = loaded
            } catch {
                let backup = url.deletingLastPathComponent().appendingPathComponent("settings-recovery-\(UUID().uuidString).json")
                try data.write(to: backup, options: .atomic)
                recoveryNotice = "Settings could not be loaded. The original was preserved at \(backup.path). Defaults are in use."
            }
        }
    }
    public func update(_ value: AppSettings) throws {
        try value.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        settings = value
    }
    public func exportData() throws -> Data { try JSONEncoder().encode(settings) }
    public func importData(_ data: Data) throws { try update(JSONDecoder().decode(AppSettings.self, from: data)) }
}
