// SPDX-License-Identifier: LicenseRef-BocaTechForce-Free-Use-No-Sale-1.0
// Copyright (c) 2026 BocaTechForce

import AppKit
import CoreGraphics

final class HoverView: NSView {
    var entered: (() -> Void)?
    var exited: (() -> Void)?
    var dragStarted: (() -> Void)?
    var dragged: ((CGFloat) -> Void)?
    var dragEnded: (() -> Void)?
    override func mouseDown(with event: NSEvent) {
        let start = NSEvent.mouseLocation.y
        dragStarted?()
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
            dragged?(NSEvent.mouseLocation.y - start)
        }
        dragEnded?()
    }
    private var area: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = area { removeTrackingArea(area) }
        let next = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(next)
        area = next
    }
    override func mouseEntered(with event: NSEvent) { entered?() }
    override func mouseExited(with event: NSEvent) { exited?() }
}

// Draw symbols explicitly in the visual center, avoiding NSButton cell offsets.
final class SymbolButton: NSButton {
    var symbol = "camera.fill"
    var fill = NSColor.systemRed
    var glyphSize: CGFloat = 30
    override func draw(_ dirtyRect: NSRect) {
        let circle = bounds.insetBy(dx: 1, dy: 1)
        (isHighlighted ? fill.withAlphaComponent(0.7) : fill).setFill()
        NSBezierPath(ovalIn: circle).fill()
        guard let source = NSImage(systemSymbolName: symbol, accessibilityDescription: toolTip)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .semibold)) else { return }
        let icon = NSImage(size: source.size, flipped: false) { rect in
            source.draw(in: rect)
            NSColor.white.setFill()
            rect.fill(using: .sourceIn)
            return true
        }
        let scale = min(glyphSize / max(1, icon.size.width), glyphSize / max(1, icon.size.height))
        let w = icon.size.width * scale, h = icon.size.height * scale
        icon.draw(in: NSRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h))
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var settingsMenu: NSMenu!
    var remainingSeconds = 0
    var countdownLabel: NSTextField?
    var menuOpen = false
    var timer: Timer?
    var expanded = false
    var root: HoverView!
    var size: CGFloat = 1
    var vertical: CGFloat = 0.5
    var dragOrigin: CGFloat = 0
    var dragging = false
    var capturePending = false
    var mouseMonitor: Any?
    var selectionPressed = false
    var captureSession = UUID()
    var captureMode = "capture"
    var activeMode = "capture"
    var isVideoCapture: Bool { activeMode == "record" || activeMode == "record-fullscreen" }
    var delaySeconds = 0
    var countdown: Timer?
    var captureStarted = false
    var overlayWatcher: Timer?
    var areaResetSeconds = 30
    var areaResetTimer: Timer?
    var delayResetSeconds = 30
    var delayResetTimer: Timer?
    var restoreFocus = true
    var previousApplication: NSRunningApplication?
    var lastExternalApplication: NSRunningApplication?
    var focusGeneration = UUID()
    let defaults = UserDefaults.standard
    var screen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if defaults.object(forKey: "vertical") != nil { vertical = CGFloat(defaults.double(forKey: "vertical")) }
        captureMode = defaults.string(forKey: "captureMode") ?? "capture"
        if !["capture", "capture-fullscreen", "scroll-capture", "record", "record-fullscreen"].contains(captureMode) { captureMode = "capture" }
        delaySeconds = defaults.integer(forKey: "delaySeconds")
        if ![0, 3, 5, 10].contains(delaySeconds) { delaySeconds = 0 }
        if defaults.object(forKey: "areaResetSeconds") != nil {
            areaResetSeconds = defaults.integer(forKey: "areaResetSeconds")
        }
        if ![0, 15, 30, 60].contains(areaResetSeconds) { areaResetSeconds = 30 }
        if defaults.object(forKey: "delayResetSeconds") != nil {
            delayResetSeconds = defaults.integer(forKey: "delayResetSeconds")
        }
        if ![0, 15, 30, 60].contains(delayResetSeconds) { delayResetSeconds = 30 }
        if defaults.object(forKey: "restoreFocus") != nil { restoreFocus = defaults.bool(forKey: "restoreFocus") }
        let saved = defaults.double(forKey: "size")
        size = saved > 0 ? CGFloat(saved) : 1
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let menu = NSMenu()
        add(menu, "Show panel", #selector(showPanel))
        add(menu, "Smaller", #selector(smaller))
        add(menu, "Larger", #selector(larger))
        let delayItem = NSMenuItem(title: "Capture delay", action: nil, keyEquivalent: "")
        let delayMenu = NSMenu()
        for seconds in [0, 3, 5, 10] {
            let item = NSMenuItem(title: seconds == 0 ? "Off" : "\(seconds) seconds", action: #selector(changeDelayMenu(_:)), keyEquivalent: "")
            item.tag = seconds
            item.target = self
            item.state = seconds == delaySeconds ? .on : .off
            delayMenu.addItem(item)
        }
        delayItem.submenu = delayMenu
        menu.addItem(delayItem)
        let resetItem = NSMenuItem(title: "Return to Area after idle", action: nil, keyEquivalent: "")
        let resetMenu = NSMenu()
        for seconds in [0, 15, 30, 60] {
            let item = NSMenuItem(title: seconds == 0 ? "Off" : "\(seconds) seconds", action: #selector(changeAreaReset(_:)), keyEquivalent: "")
            item.tag = seconds
            item.target = self
            item.state = seconds == areaResetSeconds ? .on : .off
            resetMenu.addItem(item)
        }
        resetItem.submenu = resetMenu
        menu.addItem(resetItem)
        let delayResetItem = NSMenuItem(title: "Return delay to Off after idle", action: nil, keyEquivalent: "")
        let delayResetMenu = NSMenu()
        for seconds in [0, 15, 30, 60] {
            let item = NSMenuItem(title: seconds == 0 ? "Off" : "\(seconds) seconds", action: #selector(changeDelayReset(_:)), keyEquivalent: "")
            item.tag = seconds
            item.target = self
            item.state = seconds == delayResetSeconds ? .on : .off
            delayResetMenu.addItem(item)
        }
        delayResetItem.submenu = delayResetMenu
        menu.addItem(delayResetItem)
        let focusItem = NSMenuItem(title: "Restore previous app after screenshot", action: #selector(toggleRestoreFocus(_:)), keyEquivalent: "")
        focusItem.target = self
        focusItem.state = restoreFocus ? .on : .off
        menu.addItem(focusItem)
        menu.addItem(.separator())
        add(menu, "About MacShotEdgeRibbon…", #selector(showAbout))
        add(menu, "Login startup instructions…", #selector(loginHelp))
        add(menu, "Quit MacShotEdgeRibbon", #selector(quit))
        settingsMenu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appDeactivated(_:)), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        render()
        panel.orderFrontRegardless()
        scheduleAreaReset()
        scheduleDelayReset()
    }
    func rememberExternalApplication(_ application: NSRunningApplication?) {
        guard let application = application,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !(application.bundleIdentifier ?? "").lowercased().contains("macshot"),
              !application.isTerminated else { return }
        lastExternalApplication = application
    }
    @objc func appActivated(_ notification: Notification) {
        rememberExternalApplication(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    func render() {
        let frame = screen.visibleFrame
        let width: CGFloat = expanded ? 92 * size : 10
        let height: CGFloat = 170 * size
        panel.setFrame(NSRect(x: frame.maxX - width, y: frame.minY + max(0, frame.height - height) * vertical, width: width, height: height), display: true)
        root = HoverView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.22, alpha: 0.98).cgColor
        root.layer?.cornerRadius = expanded ? 16 : 5
        root.entered = { [weak self] in self?.timer?.invalidate(); self?.setExpanded(true) }
        root.exited = { [weak self] in self?.scheduleHide() }
        root.dragStarted = { [weak self] in
            guard let self = self else { return }
            self.dragging = true
            self.timer?.invalidate()
            self.dragOrigin = self.panel.frame.minY
        }
        root.dragged = { [weak self] delta in
            guard let self = self else { return }
            let bounds = self.screen.visibleFrame
            let travel = max(0, bounds.height - self.panel.frame.height)
            let y = min(bounds.minY + travel, max(bounds.minY, self.dragOrigin + delta))
            self.vertical = travel > 0 ? (y - bounds.minY) / travel : 0.5
            self.panel.setFrameOrigin(NSPoint(x: bounds.maxX - self.panel.frame.width, y: y))
        }
        root.dragEnded = { [weak self] in
            guard let self = self else { return }
            self.dragging = false
            self.defaults.set(Double(self.vertical), forKey: "vertical")
            self.scheduleHide()
        }
        panel.contentView = root
        if !expanded {
            let line = NSView(frame: NSRect(x: 3, y: height / 2 - 18, width: 3, height: 36))
            line.wantsLayer = true
            line.layer?.backgroundColor = NSColor.systemTeal.cgColor
            line.layer?.cornerRadius = 1.5
            root.addSubview(line)
            return
        }
        // The top grip and the space around the camera belong to HoverView,
        // so dragging them moves the panel without triggering capture.
        let grip = NSView(frame: NSRect(x: width / 2 - 13 * size, y: height - 10 * size, width: 26 * size, height: 4 * size))
        grip.wantsLayer = true
        grip.layer?.backgroundColor = NSColor.gray.cgColor
        grip.layer?.cornerRadius = 2 * size
        root.addSubview(grip)
        let gear = SymbolButton(frame: NSRect(x: 8 * size, y: 130 * size, width: 24 * size, height: 24 * size))
        gear.symbol = "gearshape.fill"
        gear.fill = .systemBlue
        gear.glyphSize = 15 * size
        gear.isBordered = false
        gear.target = self
        gear.action = #selector(showSettings(_:))
        gear.toolTip = "Settings"
        root.addSubview(gear)
        let exit = SymbolButton(frame: NSRect(x: width - 32 * size, y: 130 * size, width: 24 * size, height: 24 * size))
        exit.symbol = "xmark"
        exit.fill = NSColor(calibratedRed: 0.65, green: 0.12, blue: 0.17, alpha: 1)
        exit.glyphSize = 13 * size
        exit.isBordered = false
        exit.target = self
        exit.action = #selector(quit)
        exit.toolTip = "Quit MacShotEdgeRibbon"
        root.addSubview(exit)
        let history = SymbolButton(frame: NSRect(x: (width - 24 * size) / 2, y: 130 * size, width: 24 * size, height: 24 * size))
        history.symbol = "clock.arrow.circlepath"
        history.fill = NSColor(calibratedRed: 0.38, green: 0.25, blue: 0.67, alpha: 1)
        history.glyphSize = 17 * size
        history.isBordered = false
        history.target = self
        history.action = #selector(showHistory)
        history.toolTip = "Open MacShot history"
        root.addSubview(history)
        countdownLabel = nil
        if capturePending && !captureStarted && remainingSeconds > 0 {
            let label = NSTextField(labelWithString: "\(remainingSeconds)s")
            label.font = .monospacedDigitSystemFont(ofSize: 34 * size, weight: .semibold)
            label.textColor = .systemTeal
            label.alignment = .center
            label.frame = NSRect(x: 5, y: 49 * size, width: width - 10, height: 45 * size)
            root.addSubview(label)
            countdownLabel = label
            let cancel = NSButton(title: "Cancel", target: self, action: #selector(showPanel))
            cancel.bezelStyle = .rounded
            cancel.frame = NSRect(x: 14 * size, y: 17 * size, width: width - 28 * size, height: 26 * size)
            root.addSubview(cancel)
            return
        }
        let diameter: CGFloat = 76 * size
        let button = SymbolButton(frame: NSRect(x: (width - diameter) / 2, y: 51 * size, width: diameter, height: diameter))
        button.title = ""
        button.isBordered = false
        button.fill = .systemRed
        button.symbol = "camera.fill"
        button.glyphSize = 50 * size
        button.target = self
        button.action = #selector(captureArea)
        button.toolTip = "Capture area in MacShot — drag the grip above to reposition"
        root.toolTip = "Drag up or down to reposition"
        root.addSubview(button)
        let delay = NSPopUpButton(frame: NSRect(x: 8, y: 25 * size, width: width - 16, height: 20), pullsDown: false)
        delay.font = .systemFont(ofSize: 10)
        for seconds in [0, 3, 5, 10] {
            delay.addItem(withTitle: seconds == 0 ? "Delay: Off" : "Delay: \(seconds)s")
            delay.lastItem?.tag = seconds
        }
        delay.selectItem(withTag: delaySeconds)
        delay.target = self
        delay.action = #selector(changeDelayPopup(_:))
        root.addSubview(delay)
        let modes = NSPopUpButton(frame: NSRect(x: 8, y: 2 * size, width: width - 16, height: 20), pullsDown: false)
        modes.font = .systemFont(ofSize: 10)
        modes.toolTip = "Area / Full screen / Scrolling / Record area / Record screen"
        for (title, value) in [("Area", "capture"), ("Full screen", "capture-fullscreen"), ("Scrolling", "scroll-capture"), ("Rec. area", "record"), ("Rec. screen", "record-fullscreen")] {
            modes.addItem(withTitle: title)
            modes.lastItem?.representedObject = value
            if value == captureMode { modes.select(modes.lastItem) }
        }
        modes.target = self
        modes.action = #selector(changeMode(_:))
        root.addSubview(modes)
    }
    @objc func showHistory() {
        guard !capturePending else { return }
        focusGeneration = UUID()
        timer?.invalidate()
        expanded = false
        render()
        let url = URL(string: "macshot://history")!
        if !NSWorkspace.shared.open(url) {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Could not open MacShot history"
            alert.informativeText = "Open MacShot and ensure Enable macshot:// URL scheme is checked in its settings."
            alert.runModal()
        }
    }
    @objc func changeMode(_ sender: NSPopUpButton) {
        captureMode = sender.selectedItem?.representedObject as? String ?? "capture"
        defaults.set(captureMode, forKey: "captureMode")
        scheduleAreaReset()
    }
    @objc func changeAreaReset(_ sender: NSMenuItem) {
        areaResetSeconds = sender.tag
        defaults.set(areaResetSeconds, forKey: "areaResetSeconds")
        for item in sender.menu?.items ?? [] { item.state = item.tag == areaResetSeconds ? .on : .off }
        scheduleAreaReset()
    }
    func scheduleAreaReset() {
        areaResetTimer?.invalidate()
        areaResetTimer = nil
        guard areaResetSeconds > 0, captureMode != "capture", !capturePending else { return }
        areaResetTimer = Timer.scheduledTimer(withTimeInterval: Double(areaResetSeconds), repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Do not rebuild controls while a menu or drag is in progress.
            if self.menuOpen || self.dragging { self.scheduleAreaReset(); return }
            guard !self.capturePending else { return }
            self.captureMode = "capture"
            self.defaults.set("capture", forKey: "captureMode")
            self.render()
        }
    }
    @objc func changeDelayReset(_ sender: NSMenuItem) {
        delayResetSeconds = sender.tag
        defaults.set(delayResetSeconds, forKey: "delayResetSeconds")
        for item in sender.menu?.items ?? [] { item.state = item.tag == delayResetSeconds ? .on : .off }
        scheduleDelayReset()
    }
    func scheduleDelayReset() {
        delayResetTimer?.invalidate()
        delayResetTimer = nil
        guard delayResetSeconds > 0, delaySeconds > 0, !capturePending else { return }
        delayResetTimer = Timer.scheduledTimer(withTimeInterval: Double(delayResetSeconds), repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.menuOpen || self.dragging { self.scheduleDelayReset(); return }
            guard !self.capturePending else { return }
            self.applyDelay(0)
        }
    }
    @objc func toggleRestoreFocus(_ sender: NSMenuItem) {
        restoreFocus.toggle()
        defaults.set(restoreFocus, forKey: "restoreFocus")
        sender.state = restoreFocus ? .on : .off
    }
    func restorePreviousFocus() {
        guard restoreFocus, !isVideoCapture,
              let previous = previousApplication, !previous.isTerminated,
              previous.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !(previous.bundleIdentifier ?? "").lowercased().contains("macshot") else { return }
        let generation = focusGeneration
        // Brief bounded retries handle preview creation; stop on any deliberate input
        // or switch to another external app. Never keep fighting the user's focus.
        let started = ProcessInfo.processInfo.systemUptime
        for delay in [0.0, 0.15, 0.4, 0.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.restoreFocus, !self.capturePending,
                      self.focusGeneration == generation, !previous.isTerminated,
                      let front = NSWorkspace.shared.frontmostApplication else { return }
                let idleEvents: [CGEventType] = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown, .scrollWheel]
                if idleEvents.contains(where: {
                    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) < ProcessInfo.processInfo.systemUptime - started
                }) { self.focusGeneration = UUID(); return }
                let frontIsMacShot = (front.bundleIdentifier ?? "").lowercased().contains("macshot")
                let frontIsRibbon = front.processIdentifier == ProcessInfo.processInfo.processIdentifier
                let frontIsPrevious = front.processIdentifier == previous.processIdentifier
                guard frontIsMacShot || frontIsRibbon || frontIsPrevious else { self.focusGeneration = UUID(); return }
                let macShotPIDs = Set(NSWorkspace.shared.runningApplications.filter {
                    ($0.bundleIdentifier ?? "").lowercased().contains("macshot") &&
                    $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                }.map { $0.processIdentifier })
                guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
                // Do not interrupt a remaining selection HUD or an intentionally
                // opened editor/history window. Preview thumbnails are floating panels.
                let busy = windows.contains { info in
                    guard let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
                          macShotPIDs.contains(pid.int32Value),
                          let layer = info[kCGWindowLayer as String] as? NSNumber,
                          let bounds = info[kCGWindowBounds as String] as? [String: Any],
                          let width = bounds["Width"] as? NSNumber,
                          let height = bounds["Height"] as? NSNumber else { return false }
                    return layer.intValue == 257 || layer.intValue == 258 ||
                        (layer.intValue == 0 && width.doubleValue >= 500 && height.doubleValue >= 300)
                }
                guard !busy else { return }
                if #available(macOS 14.0, *) {
                    NSApp.yieldActivation(to: previous)
                    previous.activate()
                } else {
                    previous.activate(options: [.activateIgnoringOtherApps])
                }
            }
        }
    }
    @objc func showSettings(_ sender: NSButton) {
        timer?.invalidate()
        menuOpen = true
        settingsMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
        menuOpen = false
        scheduleHide()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        restorePanel()
        return true
    }
    @objc func changeDelayPopup(_ sender: NSPopUpButton) {
        applyDelay(sender.selectedItem?.tag ?? 0)
    }
    @objc func changeDelayMenu(_ sender: NSMenuItem) { applyDelay(sender.tag) }
    func applyDelay(_ seconds: Int) {
        delaySeconds = seconds
        defaults.set(seconds, forKey: "delaySeconds")
        if let items = settingsMenu.items.first(where: { $0.title == "Capture delay" })?.submenu?.items {
            for item in items { item.state = item.tag == seconds ? .on : .off }
        }
        scheduleDelayReset()
        render()
        scheduleHide()
    }
    func setExpanded(_ value: Bool) {
        guard !capturePending, !dragging, value != expanded else { return }
        expanded = value
        render()
        if value { scheduleHide() }
    }
    func scheduleHide() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.menuOpen || self.dragging || self.panel.frame.contains(NSEvent.mouseLocation) { self.scheduleHide() }
            else { self.setExpanded(false) }
        }
    }
    @objc func showPanel() { restorePanel() }
    @objc func screenChanged() { render() }
    @objc func smaller() { size = max(0.75, size - 0.15); defaults.set(Double(size), forKey: "size"); render() }
    @objc func larger() { size = min(1.6, size + 0.15); defaults.set(Double(size), forKey: "size"); render() }
    func restorePanel() {
        let completedScreenshot = capturePending && captureStarted && !isVideoCapture
        overlayWatcher?.invalidate()
        overlayWatcher = nil
        countdown?.invalidate()
        countdown = nil
        captureStarted = false
        remainingSeconds = 0
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
        mouseMonitor = nil
        selectionPressed = false
        captureSession = UUID()
        capturePending = false
        expanded = false
        render()
        panel.orderFrontRegardless()
        scheduleAreaReset()
        scheduleDelayReset()
        if completedScreenshot { restorePreviousFocus() }
    }
    @objc func appDeactivated(_ notification: Notification) {
        guard capturePending, captureStarted, activeMode != "scroll-capture", !isVideoCapture,
              let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              (application.bundleIdentifier ?? "").lowercased().contains("macshot") else { return }
        // Fallback for cancellation or switching away before selection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.capturePending else { return }
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            if !front.lowercased().contains("macshot") { self.restorePanel() }
        }
    }
    func watchCaptureOverlay(session: UUID) {
        overlayWatcher?.invalidate()
        var sawOverlay = false
        var absentPolls = 0
        var sawRecordingHUD = false
        overlayWatcher = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] watcher in
            guard let self = self, self.capturePending, self.captureSession == session else { watcher.invalidate(); return }
            let pids = Set(NSWorkspace.shared.runningApplications.filter {
                ($0.bundleIdentifier ?? "").lowercased().contains("macshot")
            }.map { $0.processIdentifier })
            guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
            // MacShot's selection overlay is level 257, scroll HUD 258,
            // and recording HUD .statusBar + 2. Inspect metadata only.
            var recordingHUDVisible = false
            let overlayVisible = windows.contains { info in
                guard let owner = info[kCGWindowOwnerPID as String] as? NSNumber,
                      pids.contains(owner.int32Value),
                      let layer = info[kCGWindowLayer as String] as? NSNumber,
                      let bounds = info[kCGWindowBounds as String] as? [String: Any],
                      let width = bounds["Width"] as? NSNumber,
                      let height = bounds["Height"] as? NSNumber else { return false }
                if self.isVideoCapture && layer.intValue == NSWindow.Level.statusBar.rawValue + 2 {
                    recordingHUDVisible = true
                    return true
                }
                if self.activeMode == "scroll-capture" && layer.intValue == 258 { return true }
                return layer.intValue == 257 && width.doubleValue > 300 && height.doubleValue > 300
            }
            // contains may short-circuit on the selection overlay; while it
            // remains visible we already keep the companion hidden.
            if recordingHUDVisible { sawRecordingHUD = true }
            if overlayVisible { sawOverlay = true; absentPolls = 0 }
            else if sawOverlay {
                absentPolls += 1
                let threshold = self.isVideoCapture ? (sawRecordingHUD ? 8 : 25) : (self.activeMode == "scroll-capture" ? 6 : 2)
                if absentPolls >= threshold { self.restorePanel() }
            }
        }
    }
    @objc func captureArea() {
        guard !capturePending else { return }
        areaResetTimer?.invalidate()
        delayResetTimer?.invalidate()
        focusGeneration = UUID()
        rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
        previousApplication = lastExternalApplication
        activeMode = captureMode
        let url = URL(string: "macshot://\(activeMode)")!
        guard let macShotURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            scheduleAreaReset()
            scheduleDelayReset()
            alert.messageText = "MacShot area capture is unavailable"
            alert.informativeText = "Install and launch MacShot from Applications. If needed, update MacShot to a version that supports macshot://capture, then try again."
            alert.runModal()
            return
        }
        timer?.invalidate()
        capturePending = true
        panel.orderOut(nil)
        // Give the window server time to remove the entire panel before
        // MacShot freezes the screen. No Accessibility or keystroke injection.
        let session = captureSession
        let launch = { [weak self] in
            guard let self = self, self.capturePending, self.captureSession == session else { return }
            self.countdown?.invalidate()
            self.countdown = nil
            self.remainingSeconds = 0
            self.rememberExternalApplication(NSWorkspace.shared.frontmostApplication)
            self.previousApplication = self.lastExternalApplication
            self.captureStarted = true
            self.mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
                guard let self = self, self.capturePending, self.captureSession == session, self.activeMode != "scroll-capture", !self.isVideoCapture else { return }
                if event.type == .leftMouseDown {
                    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
                    self.selectionPressed = front.lowercased().contains("macshot")
                } else if self.selectionPressed {
                    self.selectionPressed = false
                    // MacShot has already frozen the screen for its selection
                    // overlay. Restoring the tab after selection cannot enter
                    // that frozen image; no need to wait for its preview toast.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                        guard let self = self, self.capturePending, self.captureSession == session else { return }
                        self.restorePanel()
                    }
                }
            }
            self.watchCaptureOverlay(session: session)
            // Plain NSWorkspace.open(url) activates MacShot *before* its URL
            // handler snapshots the previous app, losing the real capture target.
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.open([url], withApplicationAt: macShotURL, configuration: configuration) { [weak self] _, error in
                guard error != nil else { return }
                DispatchQueue.main.async {
                    guard let self = self, self.capturePending, self.captureSession == session else { return }
                    self.captureStarted = false
                    self.restorePanel()
                    NSApp.activate(ignoringOtherApps: true)
                    let alert = NSAlert()
                    alert.messageText = "Could not start MacShot"
                    alert.informativeText = "Open MacShot and ensure Enable macshot:// URL scheme is checked in its settings."
                    alert.runModal()
                }
            }
        }
        if delaySeconds == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: launch)
        } else {
            var remaining = delaySeconds
            remainingSeconds = remaining
            expanded = true
            render()
            panel.orderFrontRegardless()
            countdown = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] ticking in
                guard let self = self, self.capturePending, self.captureSession == session else { ticking.invalidate(); return }
                remaining -= 1
                if remaining <= 0 {
                    ticking.invalidate()
                    self.panel.orderOut(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: launch)
                } else {
                    self.remainingSeconds = remaining
                    self.countdownLabel?.stringValue = "\(remaining)s"
                }
            }
        }
    }
    @objc func showAbout() {
        timer?.invalidate()
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.20"
        alert.messageText = "MacShotEdgeRibbon \(version)"
        alert.informativeText = "Created by BocaTechForce — IT. Simplified.\n\nbocatechforce.com\n\nA free, source-available floating companion for MacShot.\nCopyright © 2026 BocaTechForce. BocaTechForce Free Use — No Sale License.\n\nIndependent project; not affiliated with or endorsed by MacShot. MacShot is installed separately and retains its own license.\n\nProvided as is, without warranty. See the bundled LICENSE and THIRD_PARTY_NOTICES.md for details."
        alert.addButton(withTitle: "Close")
        alert.addButton(withTitle: "BocaTechForce website")
        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://www.bocatechforce.com")!)
        }
        scheduleHide()
    }
    @objc func loginHelp() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Launch at login"
        alert.informativeText = "Open System Settings → General → Login Items (or Login Items & Extensions). Under Open at Login, click + and choose MacShotEdgeRibbon.app from your Applications folder. Remove it there to disable startup."
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
