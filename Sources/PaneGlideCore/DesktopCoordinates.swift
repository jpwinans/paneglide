import CoreGraphics

public enum DesktopCoordinates {
    public static func accessibilityFrame(from appKitFrame: CGRect, primaryTop: Double) -> CGRect { CGRect(x: appKitFrame.minX, y: primaryTop - appKitFrame.maxY, width: appKitFrame.width, height: appKitFrame.height) }
}
