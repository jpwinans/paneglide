import Foundation
import CoreGraphics

public enum WindowAction: String, Codable, CaseIterable, Sendable {
    case left, right, up, down, upperLeft, upperRight, lowerLeft, lowerRight, maximize, center
    case previousMonitor, nextMonitor, snapBack
}
public struct EdgeMargins: Codable, Equatable, Sendable {
    public var enabled = true
    public var top: Double = 0
    public var left: Double = 0
    public var bottom: Double = 0
    public var right: Double = 0
    public init() {}
}
public enum SizeUnit: String, Codable, CaseIterable, Sendable { case percent, points }
public struct Dimension: Codable, Equatable, Sendable {
    public var value: Double
    public var unit: SizeUnit
    public init(_ value: Double, _ unit: SizeUnit = .percent) { self.value = value; self.unit = unit }
    public func resolve(_ available: Double) -> Double { unit == .percent ? available * value / 100 : value }
}
public struct AlternateWidth: Codable, Equatable, Sendable {
    public var enabled = false
    public var width = Dimension(25)
    public var fitBesideCenter = false
    public init() {}
}
public struct LayoutSettings: Codable, Equatable, Sendable {
    public var alternateLeft = AlternateWidth()
    public var alternateRight = AlternateWidth()
    public var linkAlternateWidths = false
    public var margins = EdgeMargins()
    public var gapsEnabled = true
    public var horizontalGap: Double = 0
    public var verticalGap: Double = 0
    public var centerResize = true
    public var centerWidth = Dimension(50)
    public var centerHeight = Dimension(100)
    public var splitX = 0.5
    public var splitY = 0.5
    public var quarterX = 0.5
    public var quarterY = 0.5
    public init() {}
}
public enum Layout {
    public static func frame(for action: WindowAction, current: CGRect, screen: CGRect, settings: LayoutSettings = .init()) -> CGRect {
        let m = settings.margins
        let area = m.enabled ? CGRect(x: screen.minX + m.left, y: screen.minY + m.top,
            width: screen.width - m.left - m.right, height: screen.height - m.top - m.bottom) : screen
        let gx = settings.gapsEnabled ? settings.horizontalGap / 2 : 0
        let gy = settings.gapsEnabled ? settings.verticalGap / 2 : 0
        func region(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> CGRect {
            let left = area.minX + area.width * x0 + (x0 > 0 ? gx : 0)
            let top = area.minY + area.height * y0 + (y0 > 0 ? gy : 0)
            let right = area.minX + area.width * x1 - (x1 < 1 ? gx : 0)
            let bottom = area.minY + area.height * y1 - (y1 < 1 ? gy : 0)
            return CGRect(x: left, y: top, width: right - left, height: bottom - top)
        }
        func alternate(_ normal: CGRect, left: Bool) -> CGRect {
            let config = left ? settings.alternateLeft : settings.alternateRight
            guard config.enabled, current.approximatelyEquals(normal) else { return normal }
            let widthConfig = settings.linkAlternateWidths ? settings.alternateLeft : config
            let availableWidth = Double(area.width)
            let width = widthConfig.fitBesideCenter
                ? (availableWidth - min(availableWidth, settings.centerWidth.resolve(availableWidth))) / 2 - gx * 2
                : min(availableWidth, widthConfig.width.resolve(availableWidth))
            return CGRect(x: left ? area.minX : area.maxX - width, y: area.minY, width: width, height: area.height)
        }
        switch action {
        case .left: return alternate(region(0, 0, settings.splitX, 1), left: true)
        case .right: return alternate(region(settings.splitX, 0, 1, 1), left: false)
        case .up: return region(0, 0, 1, settings.splitY)
        case .down: return region(0, settings.splitY, 1, 1)
        case .upperLeft: return region(0, 0, settings.quarterX, settings.quarterY)
        case .upperRight: return region(settings.quarterX, 0, 1, settings.quarterY)
        case .lowerLeft: return region(0, settings.quarterY, settings.quarterX, 1)
        case .lowerRight: return region(settings.quarterX, settings.quarterY, 1, 1)
        case .maximize: return area
        case .center:
            let width = settings.centerResize ? min(area.width, settings.centerWidth.resolve(area.width)) : current.width
            let height = settings.centerResize ? min(area.height, settings.centerHeight.resolve(area.height)) : current.height
            return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
        default: return current
        }
    }
}

public extension CGRect {
    func approximatelyEquals(_ other: CGRect, tolerance: Double = 2) -> Bool {
        abs(minX - other.minX) <= tolerance && abs(minY - other.minY) <= tolerance &&
        abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }
}
