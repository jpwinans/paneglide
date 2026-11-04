import AppKit
@preconcurrency import ApplicationServices
import PaneGlideCore

@MainActor final class AccessibilityWindows: WindowSystem {
    private final class Entry {
        let element: AXUIElement
        let pid: pid_t
        var drawers: [CGWindowID: AXUIElement] = [:]
        init(element: AXUIElement, pid: pid_t) { self.element = element; self.pid = pid }
    }
    private var entries: [String: Entry] = [:]
    var trusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    func focusedWindow() throws -> ManagedWindow? {
        guard trusted else { throw WindowError.permissionRequired }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.15)
        guard let window: AXUIElement = attribute(kAXFocusedWindowAttribute, of: element) else { return nil }
        return try register(window, pid: app.processIdentifier)
    }
    func firstWindow(pid: pid_t) throws -> ManagedWindow {
        guard trusted else { throw WindowError.permissionRequired }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let windows: [AXUIElement] = attribute(kAXWindowsAttribute, of: app), let window = windows.first else { throw WindowError.noWindow }
        return try register(window, pid: pid)
    }
    func batchWindows(allApplications: Bool) throws -> [ManagedWindow] {
        guard trusted else { throw WindowError.permissionRequired }
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let snapshot = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let visible: [(pid_t, CGRect)] = snapshot.compactMap { info in
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), frame.width > 0, frame.height > 0 else { return nil }
            return (pid, frame)
        }
        var found: [ManagedWindow] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden && (allApplications || app.processIdentifier == frontPID) {
            let pid = app.processIdentifier
            guard visible.contains(where: { $0.0 == pid }) else { continue }
            let element = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(element, 0.15)
            let elements: [AXUIElement] = attribute(kAXWindowsAttribute, of: element) ?? []
            let candidates = elements.prefix(128).compactMap { try? register($0, pid: pid) }.filter { $0.movable && !$0.minimized && !$0.fullScreen }
            for candidate in candidates {
                // Ambiguous same-frame AX windows may belong to different Spaces;
                // leave them alone instead of guessing which one is visible.
                guard candidates.filter({ $0.frame.approximatelyEquals(candidate.frame) }).count == 1,
                      visible.contains(where: { $0.0 == pid && $0.1.approximatelyEquals(candidate.frame) }) else { continue }
                found.append(candidate)
            }
        }
        return found
    }
    private func register(_ element: AXUIElement, pid: pid_t) throws -> ManagedWindow {
        entries = entries.filter { NSRunningApplication(processIdentifier: $0.value.pid)?.isTerminated == false }
        if let pair = entries.first(where: { $0.value.pid == pid && CFEqual($0.value.element, element) }) { return try window(id: pair.key) }
        let id = UUID().uuidString
        AXUIElementSetMessagingTimeout(element, 0.15)
        entries[id] = Entry(element: element, pid: pid)
        return try window(id: id)
    }
    func window(id: String) throws -> ManagedWindow {
        guard trusted else { throw WindowError.permissionRequired }
        guard let entry = entries[id], NSRunningApplication(processIdentifier: entry.pid)?.isTerminated == false else {
            entries.removeValue(forKey: id); throw WindowError.unavailable
        }
        guard let role: String = attribute(kAXRoleAttribute, of: entry.element), role == kAXWindowRole,
              let position: AXValue = attribute(kAXPositionAttribute, of: entry.element),
              let size: AXValue = attribute(kAXSizeAttribute, of: entry.element) else {
            entries.removeValue(forKey: id); throw WindowError.unavailable
        }
        var point = CGPoint.zero; var dimensions = CGSize.zero
        guard AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize,
              AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) else { throw WindowError.unavailable }
        var result = ManagedWindow(id: id, frame: CGRect(origin: point, size: dimensions))
        var move = DarwinBoolean(false); var resize = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(entry.element, kAXPositionAttribute as CFString, &move)
        AXUIElementIsAttributeSettable(entry.element, kAXSizeAttribute as CFString, &resize)
        result.movable = move.boolValue
        result.resizable = resize.boolValue
        result.minimized = attribute(kAXMinimizedAttribute, of: entry.element) ?? false
        result.fullScreen = attribute("AXFullScreen", of: entry.element) ?? false
        let children: [AXUIElement] = (attribute(kAXChildrenAttribute, of: entry.element) ?? [])
            + attachedDrawers(to: entry, parentFrame: result.frame)
        var combined = result.frame
        for child in children.prefix(64) {
            let role: String? = attribute(kAXRoleAttribute, of: child)
            guard role == kAXDrawerRole, let position: AXValue = attribute(kAXPositionAttribute, of: child),
                  let size: AXValue = attribute(kAXSizeAttribute, of: child), AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize else { continue }
            var point = CGPoint.zero; var sizeValue = CGSize.zero
            guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &sizeValue),
                  sizeValue.width > 0, sizeValue.height > 0 else { continue }
            combined = combined.union(CGRect(origin: point, size: sizeValue))
        }
        result.drawerInsets = WindowInsets(top: result.frame.minY - combined.minY, left: result.frame.minX - combined.minX,
                                           bottom: combined.maxY - result.frame.maxY, right: combined.maxX - result.frame.maxX)
        let subrole: String? = attribute(kAXSubroleAttribute, of: entry.element)
        if subrole == kAXDialogSubrole || subrole == kAXSystemDialogSubrole { result.movable = false }
        return result
    }
    private func attachedDrawers(to entry: Entry, parentFrame: CGRect) -> [AXUIElement] {
        // Modern AppKit omits legacy NSDrawer windows from AXChildren/AXWindows.
        // On-screen bounds locate candidates; AX role and an exact parent match
        // establish attachment. An adjacent ordinary window is never a drawer.
        let snapshot = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates: [(id: CGWindowID, frame: CGRect)] = snapshot.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == entry.pid,
                  (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return (number, frame)
        }
        let visibleIDs = Set(candidates.map(\.id))
        entry.drawers = entry.drawers.filter { visibleIDs.contains($0.key) }
        guard !candidates.isEmpty else { return [] }
        let app = AXUIElementCreateApplication(entry.pid)
        AXUIElementSetMessagingTimeout(app, 0.03)
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(75))
        var found: [AXUIElement] = []
        for candidate in candidates.prefix(8) {
            guard ContinuousClock.now < deadline else { break }
            if let cached = entry.drawers[candidate.id] {
                let parent: AXUIElement? = attribute(kAXParentAttribute, of: cached)
                if let parent, CFEqual(parent, entry.element) { found.append(cached); continue }
                entry.drawers.removeValue(forKey: candidate.id)
            }
            let frame = candidate.frame
            guard !parentFrame.contains(frame) else { continue }
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(app, Float(frame.midX), Float(frame.midY), &hit) == .success else { continue }
            for _ in 0..<6 {
                guard ContinuousClock.now < deadline, let element = hit,
                      !CFEqual(element, entry.element) else { break }
                AXUIElementSetMessagingTimeout(element, 0.03)
                guard let role: String = attribute(kAXRoleAttribute, of: element) else { break }
                let parent: AXUIElement? = attribute(kAXParentAttribute, of: element)
                if role == kAXDrawerRole {
                    if let parent, CFEqual(parent, entry.element) {
                        entry.drawers[candidate.id] = element
                        found.append(element)
                    }
                    break
                }
                if role == kAXWindowRole || role == kAXApplicationRole { break }
                hit = parent
            }
        }
        return found
    }
    func displays() -> [Display] {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let candidates: [(screen: NSScreen, number: CGDirectDisplayID, stableID: String?)] = NSScreen.screens.compactMap { screen in
            let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            if CGDisplayIsInMirrorSet(number) != 0 && CGDisplayMirrorsDisplay(number) != kCGNullDirectDisplay { return nil }
            let id = CGDisplayCreateUUIDFromDisplayID(number).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
            return (screen, number, id)
        }
        let identityCounts = Dictionary(grouping: candidates.compactMap(\.stableID), by: { $0 }).mapValues(\.count)
        return candidates.map { candidate in
            let stable = candidate.stableID.map { identityCounts[$0] == 1 } ?? false
            let id = stable ? candidate.stableID! : "session-display-\(candidate.number)"
            let screen = candidate.screen
            return Display(id: id, name: screen.localizedName, visibleFrame: DesktopCoordinates.accessibilityFrame(from: screen.visibleFrame, primaryTop: top), scale: screen.backingScaleFactor, supportsProfile: stable)
        }
    }
    func apply(_ frame: CGRect, to id: String) throws -> ManagedWindow {
        let before = try window(id: id)
        guard let entry = entries[id], before.movable else { throw WindowError.unsupported }
        guard [frame.minX, frame.minY, frame.width, frame.height].allSatisfy({ $0.isFinite }), frame.width > 0, frame.height > 0 else { throw SettingsError.invalid("The requested window rectangle is invalid.") }
        // A second size request handles windows moved between displays with different bounds.
        var positionReportedFailure = false
        for _ in 0..<2 {
            var size = frame.size; var point = frame.origin
            if before.resizable, let value = AXValueCreate(.cgSize, &size) {
                let error = AXUIElementSetAttributeValue(entry.element, kAXSizeAttribute as CFString, value)
                if error == .invalidUIElement || error == .cannotComplete { throw WindowError.unavailable }
            }
            guard let value = AXValueCreate(.cgPoint, &point) else { throw WindowError.unavailable }
            let error = AXUIElementSetAttributeValue(entry.element, kAXPositionAttribute as CFString, value)
            // Legacy AppKit drawers can report generic failure after moving the
            // parent successfully. Read back before treating that response as failure.
            guard error == .success || error == .failure else { throw WindowError.unavailable }
            positionReportedFailure = positionReportedFailure || error == .failure
            Thread.sleep(forTimeInterval: 0.015)
            let actual = try window(id: id)
            if actual.frame.approximatelyEquals(frame) { return actual }
        }
        let actual = try window(id: id)
        if positionReportedFailure && actual.frame.approximatelyEquals(before.frame) { throw WindowError.unavailable }
        return actual
    }
    private func attribute<T>(_ name: String, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
