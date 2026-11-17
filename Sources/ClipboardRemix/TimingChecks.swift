#if PALETTE_CHECKS
import AppKit
import ClipboardCore

@MainActor func runTimingChecks() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("timing-check-\(UUID())")
    let board = NSPasteboard(name: .init("ClipboardRemix.TimingChecks.\(UUID())"))
    defer { board.releaseGlobally(); try? FileManager.default.removeItem(at: root) }
    let store = try HistoryStore(root: root)
    let monitor = ClipboardMonitor(pasteboard: board)
    let model = AppModel(store: store, monitor: monitor)
    func check(_ passed: Bool, _ step: String) throws {
        if !passed { throw HistoryError.message("Timing check failed: \(step)") }
    }
    var captures = 0
    monitor.onCapture = { _ in captures += 1 }
    model.pauseFor15Minutes()
    let deadline = model.resumeAt!
    try check(model.paused && deadline.timeIntervalSinceNow > 898, "15-minute deadline")
    board.clearContents(); board.setString("copied while asleep", forType: .string)
    model.refreshPause(at: deadline.addingTimeInterval(600))
    monitor.poll()
    try check(!model.paused && model.resumeAt == nil && captures == 0, "wake expiry suppresses paused clipboard")
    board.clearContents(); board.setString("copied after resume", forType: .string)
    monitor.poll()
    try check(captures == 1, "capture restarts after expiry")
    model.pauseFor15Minutes()
    let cancelledDeadline = model.resumeAt!
    board.clearContents(); board.setString("copied before manual resume", forType: .string)
    model.resumeCapture()
    monitor.poll()
    model.refreshPause(at: cancelledDeadline.addingTimeInterval(1))
    try check(!model.paused && model.resumeAt == nil && captures == 1, "manual resume cancels timer and suppresses paused clipboard")
    model.pauseFor15Minutes()
    let replacedDeadline = model.resumeAt!
    model.pauseIndefinitely()
    model.refreshPause(at: replacedDeadline.addingTimeInterval(1))
    try check(model.paused && model.resumeAt == nil, "indefinite pause replaces timed pause")
    model.resumeCapture()

    let text = try await store.capture(.text("Text copy feedback"))
    func awaitCopy() async throws {
        for _ in 0..<200 {
            if !model.isCopying { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw HistoryError.message("Timed out waiting for isolated clipboard restore")
    }
    var dismissals = 0
    model.dismiss = { dismissals += 1 }
    model.copy(text)
    try await awaitCopy()
    try check(model.feedback == "Copied" && dismissals == 1, "text feedback precedes keyboard dismissal")
    try check(board.string(forType: .string) == text.text, "text restoration")
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    memset(bitmap.bitmapData!, 128, bitmap.bytesPerRow * bitmap.pixelsHigh)
    let image = try await store.capture(.image(bitmap.representation(using: .png, properties: [:])!))
    model.copy(image, dismissAfterCopy: false)
    try await awaitCopy()
    try check(model.feedback == "Copied" && dismissals == 1, "image feedback without dismissal")
    try check(board.data(forType: .png) != nil, "image restoration")
    model.status = "Persistent test error"
    try check(model.feedback == nil, "new error clears old success")
    model.showFeedback("Copied")
    try await Task.sleep(for: .milliseconds(1_100))
    model.showFeedback("Paste sent to Test Destination")
    try await Task.sleep(for: .milliseconds(1_100))
    try check(model.feedback == "Paste sent to Test Destination", "older expiry cannot clear newer feedback")
    try await Task.sleep(for: .milliseconds(1_100))
    try check(model.feedback == nil && model.status == "Persistent test error", "feedback expiry preserves errors")
    try await store.delete(image.id)
    model.copy(image, dismissAfterCopy: false)
    try await awaitCopy()
    try check(model.feedback == nil && model.status?.hasPrefix("Copy failed:") == true, "failed image restore never shows success")
}
#endif
