import AppKit
import SwiftUI

final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class PaletteController: NSObject, NSWindowDelegate {
    let panel: PalettePanel
    private let model: AppModel
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var menuTracking = false
    private var menuObservers: [NSObjectProtocol] = []
    init(model: AppModel) {
        self.model = model
        panel = PalettePanel(contentRect: NSRect(x: 0, y: 0, width: 800, height: 530), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
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
        panel.contentView = NSHostingView(rootView: PaletteView(model: model))
        panel.delegate = self
        model.dismiss = { [weak self] in self?.hide() }
        menuObservers.append(NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuTracking = true }
        })
        menuObservers.append(NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.menuTracking = false }
        })
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
            if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = app }
            panel.center()
        }
        model.openGeneration += 1
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    func hide() {
        let restore = panel.isKeyWindow
        panel.orderOut(nil)
        if restore { previousApp?.activate(options: []) }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
}
