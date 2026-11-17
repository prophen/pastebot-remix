import SwiftUI
import ClipboardCore

/// Attach only to the large preview, never the click-to-paste history rows.
struct ImagePreviewDrag: ViewModifier {
    let item: HistoryItem
    let store: HistoryStore
    var onError: (String) -> Void
    @State private var png: Data?
    @State private var loadedID: String?

    func body(content: Content) -> some View {
        Group {
            if let png, loadedID == item.id {
                content.onDrag {
                    PNGDragProvider.make(png: png, onError: { message in
                        Task { @MainActor in onError(message) }
                    })
                }
                .help("Drag this image into a document or upload target. Dragging does not paste or remove it.")
            } else { content }
        }
        .task(id: item.id) {
            png = nil; loadedID = nil
            do {
                let data = try await store.imageData(for: item)
                guard !Task.isCancelled else { return }
                png = data; loadedID = item.id
            } catch {
                guard !Task.isCancelled else { return }
                onError("Image drag unavailable: \(error.localizedDescription)")
            }
        }
    }
}
