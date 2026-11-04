import CoreGraphics
import Testing
import PaneGlideCore

@Test func accessibilityCoordinatesIncludeLowerLaptopAndMenuBars() {
    #expect(DesktopCoordinates.accessibilityFrame(from: CGRect(x: 0, y: 0, width: 3440, height: 1410), primaryTop: 1440) == CGRect(x: 0, y: 30, width: 3440, height: 1410))
    #expect(DesktopCoordinates.accessibilityFrame(from: CGRect(x: 3440, y: -584, width: 1512, height: 949), primaryTop: 1440) == CGRect(x: 3440, y: 1075, width: 1512, height: 949))
    #expect(DesktopCoordinates.accessibilityFrame(from: CGRect(x: -1000, y: 1500, width: 1000, height: 700), primaryTop: 1440) == CGRect(x: -1000, y: -760, width: 1000, height: 700))
}
