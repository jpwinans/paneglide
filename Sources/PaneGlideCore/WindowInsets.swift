import CoreGraphics

public struct WindowInsets: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double
    public init(top: Double = 0, left: Double = 0, bottom: Double = 0, right: Double = 0) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
    }
    public func expanding(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX - left, y: frame.minY - top, width: frame.width + left + right, height: frame.height + top + bottom)
    }
    public func insetting(_ frame: CGRect) -> CGRect {
        CGRect(x: frame.minX + left, y: frame.minY + top, width: frame.width - left - right, height: frame.height - top - bottom)
    }
}
