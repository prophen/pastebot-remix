#if PALETTE_CHECKS
import AppKit
import ClipboardCore

/// Runs against the real palette/hosting view, without monitoring the system
/// clipboard, sending keystrokes, or touching the user's history/preferences.
@MainActor func runPaletteChecks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("palette-check-\(UUID())")
    let suite = "ClipboardRemix.PaletteChecks.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
    let store = try HistoryStore(root: root)
    let screen = NSScreen.screens.first!.visibleFrame
    let requested = CGRect(x: screen.minX + 60, y: screen.minY + 60, width: 1000, height: 650)
    let wanted = PaletteGeometry.restore(requested, screens: NSScreen.screens.map(\.visibleFrame))!
    defaults.set([wanted.minX, wanted.minY, wanted.width, wanted.height], forKey: "paletteFrame")
    func check(_ actual: CGRect, _ expected: CGRect, _ step: String) throws {
        guard actual == expected else {
            throw HistoryError.message("\(step): expected \(expected), got \(actual)")
        }
    }
    let model = AppModel(store: store)
    let palette = PaletteController(model: model, defaults: defaults)
    // Let the actual SwiftUI hosting view complete its initial layout.
    try await Task.sleep(for: .milliseconds(200))
    palette.panel.contentView?.layoutSubtreeIfNeeded()
    try check(palette.panel.frame, wanted, "initial hosting layout")
    _ = try await store.capture(.text(String(repeating: "A reasonably long saved clipboard item\n", count: 25)))
    try await model.reload()
    try await Task.sleep(for: .milliseconds(300))
    try check(palette.panel.frame, wanted, "history loading")
    palette.show()
    defer { palette.hide() }
    try await Task.sleep(for: .milliseconds(200))
    try check(palette.panel.frame, wanted, "first show")
    guard palette.panel.minSize == CGSize(width: 740, height: 490) else {
        throw HistoryError.message("SwiftUI replaced the palette minimum: \(palette.panel.minSize)")
    }
    let resized = PaletteGeometry.restore(CGRect(x: wanted.minX + 20, y: wanted.minY + 20, width: 900, height: 600), screens: NSScreen.screens.map(\.visibleFrame))!
    palette.panel.setFrame(resized, display: true)
    try await Task.sleep(for: .milliseconds(100))
    palette.hide()
    try await Task.sleep(for: .milliseconds(200))
    palette.show()
    try await Task.sleep(for: .milliseconds(200))
    try check(palette.panel.frame, resized, "hide/reopen")
    let minimumFrame = CGRect(x: resized.minX, y: resized.minY, width: 740, height: 490)
    palette.panel.setFrame(minimumFrame, display: true)
    try await Task.sleep(for: .milliseconds(100))
    palette.panel.performClose(nil)
    try await Task.sleep(for: .milliseconds(200))
    palette.show()
    try await Task.sleep(for: .milliseconds(200))
    try check(palette.panel.frame, minimumFrame, "minimum size / close-button reopen")
    palette.hide()
    let freshDefaults = UserDefaults(suiteName: suite)!
    let newModel = AppModel(store: store)
    let restarted = PaletteController(model: newModel, defaults: freshDefaults)
    try await newModel.reload()
    try await Task.sleep(for: .milliseconds(200))
    restarted.show()
    defer { restarted.hide() }
    try await Task.sleep(for: .milliseconds(200))
    try check(restarted.panel.frame, minimumFrame, "new controller / saved preferences")
}
#endif
