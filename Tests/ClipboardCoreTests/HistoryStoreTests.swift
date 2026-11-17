import AppKit
import ClipboardCore
import CSQLite

final class HistoryStoreTests {
    var teardown: [() -> Void] = []
    func addTeardownBlock(_ block: @escaping () -> Void) { teardown.append(block) }
    func temporaryRoot() throws -> URL {
        let root = checkTemporaryDirectory.appendingPathComponent(UUID().uuidString)
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
    func testFavoritesMigrationAndRetention() async throws {
        let root = try temporaryRoot()
        var db: OpaquePointer?
        expectEqual(sqlite3_open(root.appendingPathComponent("history.sqlite").path, &db), SQLITE_OK)
        let oldSchema = """
        CREATE TABLE clips (id TEXT PRIMARY KEY, kind TEXT NOT NULL, created REAL NOT NULL, text TEXT, image TEXT, thumbnail TEXT, width INTEGER NOT NULL, height INTEGER NOT NULL, bytes INTEGER NOT NULL);
        INSERT INTO clips VALUES ('legacy','text',1,'legacy favorite',NULL,NULL,0,0,15);
        """
        expectEqual(sqlite3_exec(db, oldSchema, nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        let store = try HistoryStore(root: root, maxItems: 3)
        expectFalse(try await store.load()[0].isPinned)
        try await store.setPinned("legacy", pinned: true)
        let image = try await store.capture(.image(png()))
        try await store.setPinned(image.id, pinned: true)
        _ = try await store.capture(.text("evicted"))
        let newest = try await store.capture(.text("new favorite match"))
        let reopened = try HistoryStore(root: root, maxItems: 3)
        try await reopened.recover()
        let rows = try await reopened.load()
        expectEqual(rows.map(\.id), [image.id, "legacy", newest.id])
        expectEqual(HistoryItem.matching(rows, query: "favorite", filter: .text).map(\.id), ["legacy", newest.id])
        expectEqual(HistoryItem.matching(rows, query: "", filter: .images).map(\.id), [image.id])
        expectEqual(HistoryItem.matching(rows, query: "favorite", filter: .images).count, 0)
        expectTrue(!(try await reopened.imageData(for: image)).isEmpty)
        try await reopened.setPinned(newest.id, pinned: true)
        do { _ = try await reopened.capture(.text("no room")); fail("Pins must block capture") } catch {}
        expectEqual(try await reopened.load().count, 3)
        // Lowering limits never removes existing pins or their image files.
        try await reopened.setLimits(items: 1, bytes: 1)
        expectEqual(try await reopened.load().count, 3)
        expectTrue(!(try await reopened.imageData(for: image)).isEmpty)
        try await reopened.setPinned(newest.id, pinned: false)
        expectEqual(try await reopened.load().count, 2)
        try await reopened.clear()
        expectTrue(try await reopened.load().isEmpty)
        expectTrue(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Images").path).isEmpty)

        let byteStore = try HistoryStore(root: temporaryRoot())
        let pinnedImage = try await byteStore.capture(.image(png()))
        try await byteStore.setPinned(pinnedImage.id, pinned: true)
        try await byteStore.setLimits(items: 3, bytes: pinnedImage.bytes)
        let distinctBitmap = try unwrap(NSBitmapImageRep(data: png()))
        distinctBitmap.bitmapData![0] = 0
        let distinctPNG = try unwrap(distinctBitmap.representation(using: .png, properties: [:]))
        do { _ = try await byteStore.capture(.image(distinctPNG)); fail("Pinned image budget must block capture") } catch {}
        _ = try await byteStore.capture(.text("text still fits"))
        expectEqual(try await byteStore.load().count, 2)
        expectEqual(try FileManager.default.contentsOfDirectory(atPath: byteStore.root.appendingPathComponent("Images").path).count, 2)
        try await byteStore.delete(pinnedImage.id)
        expectTrue(try FileManager.default.contentsOfDirectory(atPath: byteStore.root.appendingPathComponent("Images").path).isEmpty)
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
