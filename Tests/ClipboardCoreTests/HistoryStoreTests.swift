import AppKit
import ClipboardCore

final class HistoryStoreTests {
    var teardown: [() -> Void] = []
    func addTeardownBlock(_ block: @escaping () -> Void) { teardown.append(block) }
    func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func png() throws -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 40, pixelsHigh: 30, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 128, bitmap.bytesPerRow * bitmap.pixelsHigh)
        return try unwrap(bitmap.representation(using: .png, properties: [:]))
    }
    func testTextPersistsAndSearchCombinesWithFilter() async throws {
        let root = try temporaryRoot()
        let store = try HistoryStore(root: root)
        let text = "Hello café 👋\nsecond line\0after null"
        _ = try await store.capture(.text(text))
        _ = try await store.capture(.image(png()))
        let reopened = try HistoryStore(root: root)
        let items = try await reopened.load()
        expectEqual(items.count, 2)
        expectEqual(items.last?.text, text)
        expectEqual(HistoryItem.matching(items, query: "CAFÉ", filter: .all).count, 1)
        expectEqual(HistoryItem.matching(items, query: "Hello", filter: .images).count, 0)
        expectEqual(HistoryItem.matching(items, query: "", filter: .images).count, 1)
    }
    func testImagePersistenceDeletionAndRecovery() async throws {
        let root = try temporaryRoot(), store = try HistoryStore(root: root)
        let item = try await store.capture(.image(png()))
        expectEqual(item.width, 40); expectEqual(item.height, 30)
        let restored = try await store.imageData(for: item)
        let bitmap = try unwrap(NSBitmapImageRep(data: restored))
        expectTrue(bitmap.hasAlpha); expectEqual(bitmap.pixelsWide, 40)
        let clipboard = try await store.clipboardImage(for: item)
        expectEqual(clipboard.png, restored)
        expectEqual(NSBitmapImageRep(data: clipboard.tiff)?.pixelsWide, 40)
        let preview = try await store.previewData(for: item)
        expectNotNil(NSBitmapImageRep(data: preview))
        let folder = root.appendingPathComponent("Images")
        try Data([1]).write(to: folder.appendingPathComponent("orphan.png"))
        try await store.recover()
        expectFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("orphan.png").path))
        try FileManager.default.removeItem(at: folder.appendingPathComponent(item.imagePath!))
        try await store.recover()
        let rows = try await store.load()
        expectTrue(rows.isEmpty)
        expectTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }
    func testRetentionAndClearRemoveFiles() async throws {
        let root = try temporaryRoot(), store = try HistoryStore(root: root, maxItems: 2)
        _ = try await store.capture(.image(png()))
        _ = try await store.capture(.text("second"))
        _ = try await store.capture(.text("third"))
        let rows = try await store.load()
        expectEqual(rows.map(\.text), ["third", "second"])
        expectTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Images").path).isEmpty)
        _ = try await store.capture(.image(png()))
        try await store.setLimits(items: 500, bytes: 1)
        let capped = try await store.load()
        expectTrue(capped.isEmpty)
        _ = try await store.capture(.text("one"))
        try await store.clear()
        let cleared = try await store.load()
        expectTrue(cleared.isEmpty)
    }
    func testOversizeAndInvalidImagesLeaveNoFiles() async throws {
        let root = try temporaryRoot(), store = try HistoryStore(root: root, maxBytes: 10)
        for data in [Data([1, 2, 3]), try png()] {
            do { _ = try await store.capture(.image(data)); fail("Expected rejection") } catch { }
        }
        let items = try await store.load()
        expectTrue(items.isEmpty)
        expectTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Images").path).isEmpty)
    }
    func testOwnWritesAreSuppressedButLaterCopiesAreNot() {
        var tracker = ClipboardChangeTracker(initial: 5)
        expectFalse(tracker.consume(5))
        expectTrue(tracker.consume(6))
        tracker.suppress(8)
        expectFalse(tracker.consume(8))
        expectTrue(tracker.consume(9))
    }
}
