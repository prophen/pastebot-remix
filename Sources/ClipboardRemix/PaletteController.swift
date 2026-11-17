import AppKit
import SwiftUI
import ApplicationServices
import ClipboardCore

final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class PaletteController: NSObject, NSWindowDelegate {
    let panel: PalettePanel
    private let model: AppModel
    private let defaults: UserDefaults
    private var previousApp: NSRunningApplication?
    private var interactionID = UUID()
    private var keyMonitor: Any?
    private var menuTracking = false
    private var menuObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?
    private var applyingGeometry = false
    private var geometryInitialized = false
    private var activationObserver: NSObjectProtocol?
    init(model: AppModel, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.model = model
        panel = PalettePanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 530), styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "Clipboard Remix"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 740, height: 490)
        let hostingView = NSHostingView(rootView: PaletteView(model: model))
        // AppKit owns the window bounds. SwiftUI's default sizing options replace
        // minSize after layout, allowing sizes that restoreGeometry would expand.
        hostingView.sizingOptions = []
        // A root NSHostingView also writes contentMinSize/contentMaxSize to its
        // window, even with sizing disabled. A plain container isolates that.
        let container = NSView(frame: panel.contentLayoutRect)
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)
        panel.contentView = container
        restoreGeometry()
        panel.delegate = self
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.restoreGeometry() }
        }
        model.dismiss = { [weak self] in self?.hide() }
        model.pasteItem = { [weak self] item in self?.paste(item) }
        menuObservers.append(NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuTracking = true }
        })
        menuObservers.append(NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuTracking = false }
        })
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, self.panel.isVisible, !self.model.isCopying,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self.rememberDestination(app)
            }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow, !self.menuTracking, NSApp.modalWindow == nil else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers.contains(.command), !modifiers.contains(.option), !modifiers.contains(.control) {
                if let value = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(value) {
                    let rows = self.model.visible
                    if rows.count >= value { self.model.copy(rows[value - 1]) }; return nil
                }
                if event.keyCode == 51 { self.model.deleteSelected(); return nil }
            }
            guard modifiers.intersection([.command, .option, .control, .shift]).isEmpty else { return event }
            switch event.keyCode {
            case 53: self.hide(); return nil
            case 125: self.model.move(1); return nil
            case 126: self.model.move(-1); return nil
            case 36, 76: self.model.copy(); return nil
            default: return event
            }
        }
    }
    func toggle() { if panel.isVisible { hide() } else { show() } }
    func show() {
        if !panel.isVisible {
            interactionID = UUID()
            previousApp = nil
            model.pasteDestinationName = nil
            if let app = NSWorkspace.shared.frontmostApplication { rememberDestination(app) }
            restoreGeometry()
        }
        model.login.refresh()
        model.openGeneration += 1
        panel.makeKeyAndOrderFront(nil)
    }
    func hide() {
        interactionID = UUID()
        let restore = panel.isKeyWindow
        panel.orderOut(nil)
        if restore { previousApp?.activate(options: []) }
    }
    private func rememberDestination(_ app: NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !app.isTerminated else { return }
        previousApp = app
        model.pasteDestinationName = app.localizedName
        // Electron exposes its web fields only after accessibility is enabled.
        // Native apps do not need this attribute.
        if AXIsProcessTrusted(), let bundle = app.bundleURL,
           FileManager.default.fileExists(atPath: bundle.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path) {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.2)
            AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }
    }
    private func focusedField(in app: NSRunningApplication) -> AXUIElement? {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func paste(_ item: HistoryItem) {
        guard !model.isCopying else { return }
        guard let target = previousApp, !target.isTerminated else {
            model.status = "Focus a field in another app, then click the item again."
            return
        }
        guard AXIsProcessTrusted() else {
            model.status = "To paste on click, enable Clipboard Remix in System Settings → Privacy & Security → Accessibility. Then focus your destination and reopen this palette. Copy ↩ works without permission."
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            return
        }
        // Some apps expose no focused element while the palette owns keyboard
        // focus. Preserve an available snapshot, otherwise acquire it only after
        // the locked destination regains focus; never send without a field.
        var field = focusedField(in: target)
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            model.status = "Couldn’t prepare Paste. Use Copy ↩ and paste manually."
            return
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        let request = interactionID
        model.isCopying = true
        Task {
            defer { model.isCopying = false }
            do {
                try await model.restore(item, isCurrent: { self.interactionID == request })
                let changeCount = NSPasteboard.general.changeCount
                // Keep the palette visible while returning keyboard focus to the destination.
                panel.resignKey()
                guard target.activate(options: []) else { throw PasteDelivery.Failure.destinationUnavailable }
                try await PasteDelivery.deliver(
                    isCurrent: { self.interactionID == request },
                    destinationExists: { !target.isTerminated },
                    clipboardUnchanged: { NSPasteboard.general.changeCount == changeCount },
                    destinationReady: {
                        guard AXIsProcessTrusted(), target.isActive,
                              NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier,
                              let focused = self.focusedField(in: target) else { return false }
                        if field == nil { field = focused }
                        guard let field, CFEqual(field, focused) else { return false }
                        let modifiers = CGEventSource.flagsState(.combinedSessionState)
                        return modifiers.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty
                    },
                    send: { down.postToPid(target.processIdentifier); up.postToPid(target.processIdentifier) }
                )
                model.showFeedback("Paste sent to \(target.localizedName ?? "destination")")
            } catch PasteDelivery.Failure.cancelled {
                // Escape or a new palette session cancels an in-flight image/paste.
            } catch {
                guard interactionID == request else { return }
                switch error {
                case PasteDelivery.Failure.clipboardChanged:
                    model.status = "Paste cancelled because the clipboard changed. Click the item to try again."
                case PasteDelivery.Failure.destinationUnavailable:
                    model.status = "The destination app is unavailable. Focus another field, then try again."
                case PasteDelivery.Failure.timedOut:
                    model.status = "Paste couldn’t confirm focus in \(target.localizedName ?? "the destination"). Focus the field and try again, or double-click to copy."
                default:
                    model.status = "Paste failed: \(error.localizedDescription)"
                }
            }
        }
    }
    private func restoreGeometry() {
        let saved: CGRect?
        if geometryInitialized { saved = panel.frame }
        else if let values = defaults.array(forKey: "paletteFrame") as? [Double], values.count == 4 {
            saved = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        } else { saved = nil }
        guard let frame = PaletteGeometry.restore(saved, screens: NSScreen.screens.map(\.visibleFrame)) else { return }
        applyingGeometry = true
        // Permit recovery even onto a display smaller than the normal minimum.
        panel.minSize = CGSize(width: min(740, frame.width), height: min(490, frame.height))
        panel.setFrame(frame, display: panel.isVisible)
        applyingGeometry = false
        geometryInitialized = true
        saveGeometry()
    }
    private func saveGeometry() {
        guard geometryInitialized, !applyingGeometry else { return }
        let frame = panel.frame
        defaults.set([frame.origin.x, frame.origin.y, frame.width, frame.height], forKey: "paletteFrame")
    }
    func windowDidMove(_ notification: Notification) { saveGeometry() }
    func windowDidResize(_ notification: Notification) { saveGeometry() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
}
