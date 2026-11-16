import AppKit
import ClipboardCore

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var model: AppModel!
    private var palette: PaletteController!
    private var shortcut: GlobalShortcut!
    private var shiftShortcut = UserDefaults.standard.bool(forKey: "shiftShortcut")
    private var shortcutRegistered = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipboardRemix", isDirectory: true)
            model = AppModel(store: try HistoryStore(root: root))
        } catch {
            let alert = NSAlert(); alert.messageText = "Clipboard Remix couldn't open its history"; alert.informativeText = error.localizedDescription; alert.runModal(); NSApp.terminate(nil); return
        }
        installEditMenu()
        palette = PaletteController(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Remix")
        statusItem.button?.toolTip = "Clipboard Remix — click to open; right-click for controls"
        statusItem.button?.target = self; statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        shortcut = GlobalShortcut(); shortcut.onPress = { [weak self] in self?.palette.toggle() }
        shortcutRegistered = shortcut.register(shift: shiftShortcut)
        if !shortcutRegistered { model.status = "Global shortcut is unavailable. Open from the menu bar; right-click it to choose the alternate shortcut." }
        Task { await model.start(); palette.show() }
    }
    private func installEditMenu() {
        let menu = NSMenu()
        let root = NSMenuItem(); let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        root.submenu = edit; menu.addItem(root); NSApp.mainMenu = menu
    }
    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu(); menu.delegate = self
            func add(_ title: String, _ action: Selector) { let item = menu.addItem(withTitle: title, action: action, keyEquivalent: ""); item.target = self }
            add("Open Clipboard Remix", #selector(openPalette))
            add(model.paused ? "Resume Capture" : "Pause Capture", #selector(togglePause))
            menu.addItem(.separator())
            add("Shortcut: \(shiftShortcut ? "⇧⌥⌘V" : "⌥⌘V")\(shortcutRegistered ? "" : " (unavailable)") — Switch", #selector(switchShortcut))
            add("Clear History…", #selector(clearHistory))
            menu.addItem(.separator())
            add("Quit Clipboard Remix", #selector(quit))
            statusItem.menu = menu; statusItem.button?.performClick(nil)
        } else { palette.toggle() }
    }
    func menuDidClose(_ menu: NSMenu) { statusItem.menu = nil }
    @objc private func openPalette() { palette.show() }
    @objc private func togglePause() { model.paused.toggle(); statusItem.button?.image = NSImage(systemSymbolName: model.paused ? "pause.circle" : "clipboard", accessibilityDescription: "Clipboard Remix") }
    @objc private func clearHistory() { palette.show(); model.clear() }
    @objc private func switchShortcut() {
        if shortcut.register(shift: !shiftShortcut) {
            shiftShortcut.toggle(); shortcutRegistered = true; UserDefaults.standard.set(shiftShortcut, forKey: "shiftShortcut")
        } else { model.status = "That shortcut is already in use. The previous shortcut is unchanged."; palette.show() }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { palette?.show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
