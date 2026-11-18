import AppKit
import SwiftUI
import ClipboardCore

/// Native file drags interoperate with browser upload targets that do not
/// recognize a SwiftUI PNG-only item provider as a dropped file.
struct ImagePreviewDrag: ViewModifier {
    let item: HistoryItem
    let store: HistoryStore
    var onError: (String) -> Void
    var onBegan: () -> Void
    var onEnded: (Bool) -> Void
    @State private var snapshot: PNGDragSnapshot?
    @State private var loadedID: String?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let snapshot, loadedID == item.id {
                    NativeImageDrag(snapshot: snapshot, onBegan: onBegan, onEnded: onEnded)
                }
            }
            .help("Drag this image into a document or upload target. Dragging does not paste or remove it.")
            .task(id: item.id) {
                snapshot = nil; loadedID = nil
                do {
                    let png = try await store.imageData(for: item)
                    let prepared = try await PNGDragProvider.prepare(png: png)
                    guard !Task.isCancelled else { return }
                    snapshot = prepared; loadedID = item.id
                } catch {
                    guard !Task.isCancelled else { return }
                    onError("Image drag unavailable: \(error.localizedDescription)")
                }
            }
    }
}

private struct NativeImageDrag: NSViewRepresentable {
    let snapshot: PNGDragSnapshot
    var onBegan: () -> Void
    var onEnded: (Bool) -> Void
    func makeNSView(context: Context) -> ImageDragView { ImageDragView() }
    func updateNSView(_ view: ImageDragView, context: Context) {
        view.snapshot = snapshot
        view.onBegan = onBegan
        view.onEnded = onEnded
    }
}

private final class ImageDragView: NSView, NSDraggingSource {
    var snapshot: PNGDragSnapshot?
    var onBegan: (() -> Void)?
    var onEnded: ((Bool) -> Void)?
    private var dragSnapshot: PNGDragSnapshot?
    private var start: NSPoint?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { start = event.locationInWindow }
    override func mouseUp(with event: NSEvent) { start = nil }
    override func mouseDragged(with event: NSEvent) {
        guard let start, dragSnapshot == nil, let snapshot,
              hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4,
              let image = NSImage(data: snapshot.png) else { return }
        self.start = nil
        dragSnapshot = snapshot
        let drag = NSDraggingItem(pasteboardWriter: snapshot)
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height, 1)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        drag.setDraggingFrame(NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                                     width: size.width, height: size.height), contents: image)
        onBegan?()
        let session = beginDraggingSession(with: [drag], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        dragSnapshot = nil; start = nil
        onEnded?(!operation.isEmpty)
    }
}
