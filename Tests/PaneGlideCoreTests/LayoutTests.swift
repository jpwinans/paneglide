import Foundation
import CoreGraphics
import Testing
import PaneGlideCore

@Test func leftUsesUsableDesktop() {
    #expect(Layout.frame(for: .left, current: .zero, screen: CGRect(x: 0, y: 30, width: 2000, height: 1000)) == CGRect(x: 0, y: 30, width: 1000, height: 1000))
}

@Test func allStandardRegions() {
    let screen = CGRect(x: -2000, y: 50, width: 2000, height: 1000)
    let cases: [(WindowAction, CGRect)] = [
        (.right, CGRect(x: -1000, y: 50, width: 1000, height: 1000)),
        (.up, CGRect(x: -2000, y: 50, width: 2000, height: 500)),
        (.down, CGRect(x: -2000, y: 550, width: 2000, height: 500)),
        (.upperLeft, CGRect(x: -2000, y: 50, width: 1000, height: 500)),
        (.upperRight, CGRect(x: -1000, y: 50, width: 1000, height: 500)),
        (.lowerLeft, CGRect(x: -2000, y: 550, width: 1000, height: 500)),
        (.lowerRight, CGRect(x: -1000, y: 550, width: 1000, height: 500)),
        (.maximize, screen)
    ]
    for (action, expected) in cases { #expect(Layout.frame(for: action, current: .zero, screen: screen) == expected) }
}

@Test func partitionsAreIndependent() {
    var settings = LayoutSettings()
    settings.splitX = 0.6
    settings.splitY = 0.4
    settings.quarterX = 0.3
    settings.quarterY = 0.7
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    #expect(Layout.frame(for: .left, current: .zero, screen: screen, settings: settings) == CGRect(x: 0, y: 0, width: 1200, height: 1000))
    #expect(Layout.frame(for: .right, current: .zero, screen: screen, settings: settings) == CGRect(x: 1200, y: 0, width: 800, height: 1000))
    #expect(Layout.frame(for: .down, current: .zero, screen: screen, settings: settings) == CGRect(x: 0, y: 400, width: 2000, height: 600))
    #expect(Layout.frame(for: .upperRight, current: .zero, screen: screen, settings: settings) == CGRect(x: 600, y: 0, width: 1400, height: 700))
}

@Test func marginsAndGaps() {
    var s = LayoutSettings()
    s.margins.left = 20; s.margins.top = 10; s.margins.right = 40; s.margins.bottom = 30
    s.horizontalGap = 20; s.verticalGap = 10
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    #expect(Layout.frame(for: .left, current: .zero, screen: screen, settings: s) == CGRect(x: 20, y: 10, width: 960, height: 960))
    #expect(Layout.frame(for: .upperRight, current: .zero, screen: screen, settings: s) == CGRect(x: 1000, y: 10, width: 960, height: 475))
    s.margins.enabled = false; s.gapsEnabled = false
    #expect(Layout.frame(for: .left, current: .zero, screen: screen, settings: s) == CGRect(x: 0, y: 0, width: 1000, height: 1000))
}

@Test func centerRespectsBothDimensionsAndMode() {
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    let current = CGRect(x: 50, y: 60, width: 400, height: 200)
    var s = LayoutSettings()
    s.centerWidth = Dimension(60); s.centerHeight = Dimension(80)
    #expect(Layout.frame(for: .center, current: current, screen: screen, settings: s) == CGRect(x: 400, y: 100, width: 1200, height: 800))
    s.centerWidth = Dimension(800, .points); s.centerHeight = Dimension(600, .points)
    #expect(Layout.frame(for: .center, current: current, screen: screen, settings: s) == CGRect(x: 600, y: 200, width: 800, height: 600))
    s.centerResize = false
    #expect(Layout.frame(for: .center, current: current, screen: screen, settings: s) == CGRect(x: 800, y: 400, width: 400, height: 200))
}

@Test func alternatesUseConfiguredSplitAndIndependentWidths() {
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    var s = LayoutSettings()
    s.splitX = 0.6
    s.alternateLeft.enabled = true; s.alternateLeft.width = Dimension(15)
    s.alternateRight.enabled = true; s.alternateRight.width = Dimension(400, .points)
    let left = Layout.frame(for: .left, current: .zero, screen: screen, settings: s)
    #expect(left == CGRect(x: 0, y: 0, width: 1200, height: 1000))
    let narrow = Layout.frame(for: .left, current: left, screen: screen, settings: s)
    #expect(narrow == CGRect(x: 0, y: 0, width: 300, height: 1000))
    #expect(Layout.frame(for: .left, current: narrow, screen: screen, settings: s) == left)
    let right = CGRect(x: 1200, y: 0, width: 800, height: 1000)
    #expect(Layout.frame(for: .right, current: right, screen: screen, settings: s) == CGRect(x: 1600, y: 0, width: 400, height: 1000))
    s.alternateLeft.enabled = false
    #expect(Layout.frame(for: .left, current: left, screen: screen, settings: s) == left)
}

@Test func fitTracksCenterAndGaps() {
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    var s = LayoutSettings()
    s.alternateLeft.enabled = true; s.alternateLeft.fitBesideCenter = true
    s.alternateRight.enabled = true; s.alternateRight.fitBesideCenter = true
    s.centerWidth = Dimension(60); s.centerHeight = Dimension(80)
    let left = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let right = CGRect(x: 1000, y: 0, width: 1000, height: 1000)
    #expect(Layout.frame(for: .left, current: left, screen: screen, settings: s) == CGRect(x: 0, y: 0, width: 400, height: 1000))
    #expect(Layout.frame(for: .right, current: right, screen: screen, settings: s) == CGRect(x: 1600, y: 0, width: 400, height: 1000))
    s.centerWidth = Dimension(40); s.centerHeight = Dimension(60)
    #expect(Layout.frame(for: .left, current: left, screen: screen, settings: s) == CGRect(x: 0, y: 0, width: 600, height: 1000))
    #expect(Layout.frame(for: .center, current: .zero, screen: screen, settings: s) == CGRect(x: 600, y: 200, width: 800, height: 600))
    s.centerWidth = Dimension(50); s.centerHeight = Dimension(100)
    s.margins.left = 20; s.margins.right = 40; s.margins.top = 10; s.margins.bottom = 30
    s.horizontalGap = 20
    #expect(Layout.frame(for: .left, current: CGRect(x: 20, y: 10, width: 960, height: 960), screen: screen, settings: s) == CGRect(x: 20, y: 10, width: 465, height: 960))
}

@Test func manualChangesAndTolerance() {
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    var s = LayoutSettings(); s.alternateLeft.enabled = true
    #expect(Layout.frame(for: .left, current: CGRect(x: 2, y: 0, width: 1000, height: 1000), screen: screen, settings: s).width == 500)
    #expect(Layout.frame(for: .left, current: CGRect(x: 3, y: 0, width: 1000, height: 1000), screen: screen, settings: s).width == 1000)
    #expect(Layout.frame(for: .left, current: CGRect(x: 0, y: 0, width: 1000, height: 900), screen: screen, settings: s).width == 1000)
    s.alternateLeft.width = Dimension(50)
    #expect(Layout.frame(for: .left, current: CGRect(x: 0, y: 0, width: 1000, height: 1000), screen: screen, settings: s).width == 1000)
}

@Test func linkedFitUsesLeftRuleForBothSides() throws {
    let screen = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    var settings = LayoutSettings()
    settings.alternateLeft.enabled = true
    settings.alternateRight.enabled = true
    settings.linkAlternateWidths = true
    settings.alternateLeft.fitBesideCenter = true
    settings.centerWidth = Dimension(60)
    let normalRight = CGRect(x: 1000, y: 0, width: 1000, height: 1000)
    #expect(Layout.frame(for: .right, current: normalRight, screen: screen, settings: settings) == CGRect(x: 1600, y: 0, width: 400, height: 1000))
    settings.alternateLeft.enabled = false
    settings.centerResize = false
    #expect(throws: SettingsError.self) { try settings.validate() }
}
