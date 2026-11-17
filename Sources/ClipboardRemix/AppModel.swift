import AppKit
import SwiftUI
import ClipboardCore

@MainActor final class AppModel: ObservableObject {
    @Published var items: [HistoryItem] = []
    @Published var query = "" { didSet { reconcileSelection() } }
    @Published var filter: ClipFilter = .all { didSet { reconcileSelection() } }
    @Published var selectedID: String?
    @Published private(set) var paused = false
    @Published private(set) var resumeAt: Date?
    @Published private(set) var feedback: String?
    @Published var status: String? {
        didSet { if status != nil { clearFeedback() } }
    }
    @Published var isCopying = false
    @Published var openGeneration = 0
    @Published var pasteDestinationName: String?
    let login = LoginController()
    let store: HistoryStore
    let monitor: ClipboardMonitor
    var dismiss: (() -> Void)?
    var pasteItem: ((HistoryItem) -> Void)?
    var visible: [HistoryItem] { HistoryItem.matching(items, query: query, filter: filter) }
    var selected: HistoryItem? { visible.first { $0.id == selectedID } }
    private var pending = 0
    private var pauseState = CapturePause()
    private var pauseTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var feedbackState = BriefFeedback()
    private var feedbackTask: Task<Void, Never>?
    var pauseDescription: String {
        if let resumeAt { return "Paused until \(resumeAt.formatted(date: .omitted, time: .shortened))" }
        return paused ? "Capture paused" : "Capture running"
    }
    init(store: HistoryStore, monitor: ClipboardMonitor? = nil) {
        self.store = store; self.monitor = monitor ?? ClipboardMonitor()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPause() }
        }
    }
    deinit {
        pauseTimer?.invalidate()
        feedbackTask?.cancel()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }
    func pauseIndefinitely() {
        pauseState.pause()
        applyPauseState()
    }
    func pauseFor15Minutes() {
        pauseState.pause(until: Date().addingTimeInterval(15 * 60))
        applyPauseState()
    }
    func resumeCapture() {
        pauseState.resume()
        applyPauseState()
    }
    func togglePause() { if paused { resumeCapture() } else { pauseIndefinitely() } }
    func refreshPause(at now: Date = Date()) {
        if pauseState.expire(at: now) { applyPauseState() }
    }
    private func applyPauseState() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        // Setting monitor.paused suppresses the current change count, including
        // the clipboard copied during sleep or immediately before manual Resume.
        monitor.paused = pauseState.isPaused
        paused = pauseState.isPaused
        resumeAt = pauseState.resumeAt
        if resumeAt != nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPause() }
            }
            RunLoop.main.add(timer, forMode: .common)
            pauseTimer = timer
        }
    }
    func showFeedback(_ message: String) {
        feedbackTask?.cancel()
        let id = feedbackState.show(message, at: Date())
        let deadline = feedbackState.expiresAt!
        feedback = feedbackState.message
        feedbackTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self else { return }
            if self.feedbackState.expire(id, at: deadline) { self.feedback = nil }
        }
    }
    func clearFeedback() {
        feedbackTask?.cancel()
        feedbackTask = nil
        feedbackState.clear()
        feedback = nil
    }
    func start() async {
        do { try await store.recover(); try await reload() } catch { status = error.localizedDescription }
        monitor.onCapture = { [weak self] payload in
            guard let self else { return }
            guard self.pending < 2 else { self.status = "Capture queue full; a copy was skipped."; return }
            self.pending += 1
            Task {
                defer { self.pending -= 1 }
                do { try await self.store.capture(payload); try await self.reload() }
                catch { self.status = error.localizedDescription }
            }
        }
        monitor.start()
    }
    func reload() async throws { items = try await store.load(); reconcileSelection() }
    func reconcileSelection() {
        if !visible.contains(where: { $0.id == selectedID }) { selectedID = visible.first?.id }
    }
    func move(_ delta: Int) {
        let rows = visible
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == selectedID } ?? 0
        selectedID = rows[min(max(index + delta, 0), rows.count - 1)].id
    }
    func copy(_ item: HistoryItem? = nil, dismissAfterCopy: Bool = true) {
        guard !isCopying, let item = item ?? selected else { return }
        isCopying = true
        Task {
            defer { isCopying = false }
            do {
                try await restore(item)
                showFeedback("Copied")
                if dismissAfterCopy { dismiss?() }
            } catch { status = "Copy failed: \(error.localizedDescription)" }
        }
    }
    func restore(_ item: HistoryItem, isCurrent: () -> Bool = { true }) async throws {
        let ok: Bool
        if let text = item.text {
            guard isCurrent() else { throw PasteDelivery.Failure.cancelled }
            ok = monitor.restore(text: text)
        } else {
            let data = try await store.clipboardImage(for: item)
            guard isCurrent() else { throw PasteDelivery.Failure.cancelled }
            ok = monitor.restore(image: data.png, tiff: data.tiff)
        }
        guard ok else { throw HistoryError.message("Couldn't write to the clipboard. Try again.") }
    }
    func togglePin(_ item: HistoryItem) {
        Task {
            do { try await store.setPinned(item.id, pinned: !item.isPinned); try await reload() }
            catch { status = error.localizedDescription }
        }
    }
    func deleteSelected() {
        guard let id = selectedID else { return }
        Task { do { try await store.delete(id); try await reload() } catch { status = error.localizedDescription } }
    }
    func clear() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "This removes all saved text and images, including pinned favorites. Your current system clipboard is unchanged."
        alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Clear History")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        Task { do { try await store.clear(); try await reload() } catch { status = error.localizedDescription } }
    }
}
