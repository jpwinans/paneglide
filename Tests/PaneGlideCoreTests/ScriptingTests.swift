import Foundation
import CoreGraphics
import Testing
import PaneGlideCore

@Test func customGeometryThirdsAnchorsAndGrids() throws {
    let screen = CGRect(x: -1200, y: 30, width: 1200, height: 900)
    let current = CGRect(x: -1000, y: 100, width: 400, height: 300)
    let settings = LayoutSettings()
    #expect(try CustomGeometry.grid(CGRect(x: 1, y: 0, width: 1, height: 1), columns: 3, rows: 1).frame(current: current, screen: screen, settings: settings) == CGRect(x: -800, y: 30, width: 400, height: 900))
    #expect(try CustomGeometry.anchor(x: 1, y: 1).frame(current: current, screen: screen, settings: settings) == CGRect(x: -400, y: 630, width: 400, height: 300))
    #expect(try CustomGeometry.anchor(x: 0, y: nil).frame(current: current, screen: screen, settings: settings) == CGRect(x: -1200, y: 100, width: 400, height: 300))
    #expect(try CustomGeometry.move(CGPoint(x: 40, y: 50)).frame(current: current, screen: screen, settings: settings) == CGRect(x: -1160, y: 80, width: 400, height: 300))
    #expect(try CustomGeometry.resize(CGSize(width: 600, height: 400)).frame(current: current, screen: screen, settings: settings) == CGRect(x: -1000, y: 100, width: 600, height: 400))
    #expect(try CustomGeometry.rectangle(CGRect(x: 20, y: 30, width: 600, height: 400)).frame(current: current, screen: screen, settings: settings) == CGRect(x: -1180, y: 60, width: 600, height: 400))
    #expect(throws: SettingsError.self) { try CustomGeometry.grid(CGRect(x: 5, y: 0, width: 2, height: 1), columns: 6, rows: 6).frame(current: current, screen: screen, settings: settings) }
}

@Test @MainActor func scriptGeometryUsesMonitorProfilesAndSnapBack() throws {
    let external = TestWindowSystem(); let engine = WindowCommands(system: external)
    external.screens.append(Display(id: "laptop", visibleFrame: CGRect(x: -1200, y: 30, width: 1200, height: 900)))
    let initial = try external.window(id: "one").frame
    let settings = AppSettings()
    #expect(try engine.execute(CustomGeometry.rectangle(CGRect(x: 20, y: 30, width: 600, height: 400)), onMonitor: 2, settings: settings).actual == CGRect(x: -1180, y: 60, width: 600, height: 400))
    #expect(try engine.execute(.snapBack, settings: settings).actual == initial)
    #expect(try engine.execute(.right, onMonitor: 2, settings: settings).actual == CGRect(x: -600, y: 30, width: 600, height: 900))
    let beforeInvalid = try external.window(id: "one").frame
    #expect(throws: SettingsError.self) { try engine.execute(.left, onMonitor: 3, settings: settings) }
    #expect(try external.window(id: "one").frame == beforeInvalid)
}

@Test func tileAndCascadeLayoutsAreBounded() throws {
    let area = CGRect(x: 0, y: 0, width: 2000, height: 1000)
    let tiles = try BatchArrangement.tile.geometries(count: 3, area: area).map { try $0.frame(current: .zero, screen: area, settings: LayoutSettings()) }
    #expect(tiles == [CGRect(x: 0, y: 0, width: 1000, height: 500), CGRect(x: 1000, y: 0, width: 1000, height: 500), CGRect(x: 0, y: 500, width: 1000, height: 500)])
    let cascade = try BatchArrangement.cascade.geometries(count: 3, area: area).map { try $0.frame(current: .zero, screen: area, settings: LayoutSettings()) }
    #expect(cascade == [CGRect(x: 0, y: 0, width: 1500, height: 750), CGRect(x: 24, y: 24, width: 1500, height: 750), CGRect(x: 48, y: 48, width: 1500, height: 750)])
    #expect(try BatchArrangement.tile.geometries(count: 0, area: area).isEmpty)
    #expect(throws: SettingsError.self) { try BatchArrangement.tile.geometries(count: 65, area: area) }
}
