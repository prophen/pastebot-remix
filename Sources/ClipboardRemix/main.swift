import AppKit
import ClipboardCore
import ServiceManagement
import Combine

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var model: AppModel!
    private var palette: PaletteController!
    private var shortcut: GlobalShortcut!
    private var shiftShortcut = UserDefaults.standard.bool(forKey: "shiftShortcut")
    private var shortcutRegistered = false
    private var subscriptions = Set<AnyCancellable>()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        do {
            let root = AppLocations.dataDirectory
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
        model.$paused.combineLatest(model.$resumeAt, model.$feedback)
            .sink { [weak self] paused, resumeAt, feedback in
                self?.updateStatusItem(paused: paused, resumeAt: resumeAt, feedback: feedback)
            }.store(in: &subscriptions)
        shortcut = GlobalShortcut(); shortcut.onPress = { [weak self] in self?.palette.toggle() }
        shortcutRegistered = shortcut.register(shift: shiftShortcut)
        if !shortcutRegistered { model.status = "Global shortcut is unavailable. Open from the menu bar; right-click it to choose the alternate shortcut." }
        Task { await model.start() }
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
            if model.paused {
                let state = menu.addItem(withTitle: model.pauseDescription, action: nil, keyEquivalent: "")
                state.isEnabled = false
                state.tag = 101
                add("Resume Capture", #selector(resumeCapture))
            }
            add("Pause for 15 Minutes", #selector(pauseFor15Minutes))
            add("Pause Indefinitely", #selector(pauseIndefinitely))
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
    private func updateStatusItem(paused: Bool, resumeAt: Date?, feedback: String?) {
        statusItem.button?.image = NSImage(systemSymbolName: paused ? "pause.circle" : "clipboard", accessibilityDescription: "Clipboard Remix")
        // Keep confirmation visible after keyboard copy dismisses the palette.
        statusItem.length = feedback == nil ? NSStatusItem.squareLength : NSStatusItem.variableLength
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.title = feedback.map { $0 == "Copied" ? " Copied" : " Paste sent" } ?? ""
        let capture = paused ? resumeAt.map { "Capture paused until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Capture paused indefinitely" : "Capturing"
        if let state = statusItem.menu?.item(withTag: 101) {
            state.title = capture
        }
        statusItem.button?.toolTip = feedback ?? "Clipboard Remix — \(capture). Click to open; right-click for controls."
    }
    @objc private func resumeCapture() { model.resumeCapture() }
    @objc private func pauseFor15Minutes() { model.pauseFor15Minutes() }
    @objc private func pauseIndefinitely() { model.pauseIndefinitely() }
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
#if PALETTE_CHECKS
    if CommandLine.arguments.contains("--check-palette") {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        Task {
            do { try await runPaletteChecks(); print("PASS native palette layout/persistence, timed pause and copy feedback"); exit(0) }
            catch { print("FAIL native palette checks: \(error)"); exit(1) }
        }
        app.run()
        exit(1)
    }
#endif
    if CommandLine.arguments.contains("--diagnostics") {
        let details: [String: Any] = [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "",
            "bundle": Bundle.main.bundleURL.path,
            "dataDirectory": AppLocations.dataDirectory.path,
            "dragExportDirectory": AppLocations.dragExportDirectory.path,
            "loginLocationSupported": AppLocations.supportsLogin(bundleURL: Bundle.main.bundleURL),
            "loginStatus": SMAppService.mainApp.status.rawValue
        ]
        if let data = try? JSONSerialization.data(withJSONObject: details, options: [.prettyPrinted, .sortedKeys]),
           let output = String(data: data, encoding: .utf8) { print(output) }
        exit(0)
    }
    if CommandLine.arguments.contains("--login-status") {
        print("Launch at Login system status: \(SMAppService.mainApp.status.rawValue) (0=off, 1=enabled, 2=requires approval, 3=not found)")
        exit(0)
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
