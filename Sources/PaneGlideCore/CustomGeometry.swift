import Foundation
import CoreGraphics

public enum CustomGeometry: Sendable {
    case move(CGPoint), resize(CGSize), rectangle(CGRect)
    case anchor(x: Double?, y: Double?)
    case grid(CGRect, columns: Int, rows: Int)
    public func frame(current: CGRect, screen: CGRect, settings: LayoutSettings) throws -> CGRect {
        try settings.validate(screen: screen)
        let area = Layout.frame(for: .maximize, current: current, screen: screen, settings: settings)
        var result = current
        switch self {
        case .move(let point): result.origin = CGPoint(x: area.minX + point.x, y: area.minY + point.y)
        case .resize(let size): result.size = size
        case .rectangle(let rect): result = rect.offsetBy(dx: area.minX, dy: area.minY)
        case .anchor(let x, let y):
            for fraction in [x, y].compactMap({ $0 }) where !fraction.isFinite || !(0...1).contains(fraction) {
                throw SettingsError.invalid("Anchor fractions must be between zero and one.")
            }
            if let x { result.origin.x = area.minX + (area.width - current.width) * x }
            if let y { result.origin.y = area.minY + (area.height - current.height) * y }
        case .grid(let cells, let columns, let rows):
            guard columns > 0, rows > 0, cells.minX >= 0, cells.minY >= 0, cells.width > 0, cells.height > 0,
                  cells.maxX <= Double(columns), cells.maxY <= Double(rows),
                  [cells.minX, cells.minY, cells.width, cells.height].allSatisfy({ $0.isFinite && $0.rounded() == $0 }) else {
                throw SettingsError.invalid("Grid cells must be positive whole sizes inside a positive grid, starting at zero.")
            }
            let gx = settings.gapsEnabled ? settings.horizontalGap / 2 : 0
            let gy = settings.gapsEnabled ? settings.verticalGap / 2 : 0
            let left = area.minX + area.width * cells.minX / Double(columns) + (cells.minX > 0 ? gx : 0)
            let top = area.minY + area.height * cells.minY / Double(rows) + (cells.minY > 0 ? gy : 0)
            let right = area.minX + area.width * cells.maxX / Double(columns) - (cells.maxX < Double(columns) ? gx : 0)
            let bottom = area.minY + area.height * cells.maxY / Double(rows) - (cells.maxY < Double(rows) ? gy : 0)
            result = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        }
        guard [result.minX, result.minY, result.width, result.height].allSatisfy({ $0.isFinite }), result.width > 0, result.height > 0 else {
            throw SettingsError.invalid("The requested rectangle must be finite with positive width and height.")
        }
        return result
    }
}

public enum BatchArrangement: Sendable {
    case tile, cascade
    public func geometries(count: Int, area: CGRect) throws -> [CustomGeometry] {
        guard (0...64).contains(count), area.width.isFinite, area.height.isFinite, area.width > 0, area.height > 0 else {
            throw SettingsError.invalid("Batch arrangement supports up to 64 windows on a usable display.")
        }
        guard count > 0 else { return [] }
        switch self {
        case .tile:
            let columns = Int(ceil(sqrt(Double(count))))
            let rows = (count + columns - 1) / columns
            return (0..<count).map { .grid(CGRect(x: $0 % columns, y: $0 / columns, width: 1, height: 1), columns: columns, rows: rows) }
        case .cascade:
            let steps = max(1, Int(min(area.width, area.height) * 0.25 / 24) + 1)
            return (0..<count).map { index in
                let offset = Double(index % steps) * 24
                return .rectangle(CGRect(x: offset, y: offset, width: area.width * 0.75, height: area.height * 0.75))
            }
        }
    }
}
