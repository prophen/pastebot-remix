import AppKit
import ClipboardCore
import CSQLite

final class DeduplicationTests {
    func run() async throws {
        let fixture = HistoryStoreTests()
        defer { for cleanup in fixture.teardown { cleanup() } }
        let root = try fixture.temporaryRoot()
        let store = try HistoryStore(root: root)
        let exact = " café 👋\nline\0tail "
        let original = try await store.capture(.text(exact))
        let other = try await store.capture(.text("different"))
        let again = try await store.capture(.text(exact))
        expectEqual(again.id, original.id)
        expectTrue(again.created > other.created)
        expectEqual(try await store.load().map(\.id), [original.id, other.id])
        _ = try await store.capture(.text(exact.trimmingCharacters(in: .whitespacesAndNewlines)))
        let composed = try await store.capture(.text("\u{00e9}"))
        let decomposed = try await store.capture(.text("e\u{0301}"))
        expectTrue(composed.id != decomposed.id)
        expectEqual(try await store.load().count, 5)
        try await store.setPinned(original.id, pinned: true)
        try await store.setLimits(items: 1, bytes: 500_000_000)
        let full = try await store.capture(.text(exact))
        expectEqual(full.id, original.id); expectTrue(full.isPinned)
        expectEqual(try await store.load().count, 1)
        let reopened = try HistoryStore(root: root, maxItems: 1)
        let afterRestart = try await reopened.capture(.text(exact))
        expectEqual(afterRestart.id, original.id); expectTrue(afterRestart.isPinned)
        expectEqual(try await reopened.load().count, 1)

        let imageRoot = try fixture.temporaryRoot()
        let imageStore = try HistoryStore(root: imageRoot)
        let png = try imageData(red: 30, type: .png)
        let tiff = try imageData(red: 30, type: .tiff)
        let firstImage = try await imageStore.capture(.image(png))
        _ = try await imageStore.capture(.text("intervening copy"))
        let equivalent = try await imageStore.capture(.image(tiff))
        expectEqual(equivalent.id, firstImage.id)
        expectEqual(equivalent.imagePath, firstImage.imagePath)
        expectEqual(try await imageStore.load().first?.id, firstImage.id)
        expectEqual(try files(imageRoot).count, 2)
        let distinct = try await imageStore.capture(.image(imageData(red: 160, type: .png)))
        expectTrue(distinct.id != firstImage.id)
        let dimensionChange = try await imageStore.capture(.image(imageData(red: 30, type: .png, width: 17)))
        expectTrue(dimensionChange.id != firstImage.id)

        // Artificially force a candidate hash collision. The more recent image
        // must not match until complete normalized pixel equality is checked.
        try sql(imageRoot, "UPDATE clips SET fingerprint = (SELECT fingerprint FROM clips WHERE id = '\(firstImage.id)') WHERE id = '\(distinct.id)'")
        let collisionSafe = try await imageStore.capture(.image(png))
        expectEqual(collisionSafe.id, firstImage.id)
        expectEqual(try await imageStore.load().count, 4)
        expectEqual(try files(imageRoot).count, 6)

        // Existing migrations leave fingerprints NULL; recopy computes them
        // lazily while keeping the original files and pinned identity.
        try await imageStore.setPinned(firstImage.id, pinned: true)
        try sql(imageRoot, "UPDATE clips SET fingerprint = NULL WHERE id = '\(firstImage.id)'")
        let imageReopened = try HistoryStore(root: imageRoot)
        let legacyMatch = try await imageReopened.capture(.image(tiff))
        expectEqual(legacyMatch.id, firstImage.id); expectTrue(legacyMatch.isPinned)
        try await imageReopened.setLimits(items: 1, bytes: 1)
        let fullImage = try await imageReopened.capture(.image(png))
        expectEqual(fullImage.id, firstImage.id); expectTrue(fullImage.isPinned)
        expectEqual(try await imageReopened.load().count, 1)
        expectEqual(try files(imageRoot).count, 2)
        let bytes = try await imageReopened.imageData(for: fullImage)
        expectTrue(!bytes.isEmpty)

        let alphaRoot = try fixture.temporaryRoot()
        let alphaStore = try HistoryStore(root: alphaRoot)
        let alphaPNG = try imageData(red: 30, type: .png, alpha: 128)
        let alphaTIFF = try imageData(red: 30, type: .tiff, alpha: 128)
        let alphaOriginal = try await alphaStore.capture(.image(alphaPNG))
        let alphaEquivalent = try await alphaStore.capture(.image(alphaTIFF))
        expectEqual(alphaEquivalent.id, alphaOriginal.id)
        let normalizedPNG = try await alphaStore.imageData(for: alphaOriginal)
        let normalizedRecopy = try await alphaStore.capture(.image(normalizedPNG))
        expectEqual(normalizedRecopy.id, alphaOriginal.id)
        expectEqual(try await alphaStore.load().count, 1)
        expectEqual(try files(alphaRoot).count, 2)
        expectTrue(try unwrap(NSBitmapImageRep(data: normalizedPNG)).hasAlpha)

        // A missing original cannot cause a good new copy to be discarded.
        try await imageReopened.setLimits(items: 5, bytes: 500_000_000)
        try FileManager.default.removeItem(at: imageRoot.appendingPathComponent("Images").appendingPathComponent(firstImage.imagePath!))
        let replacement = try await imageReopened.capture(.image(png))
        expectTrue(replacement.id != firstImage.id)
        try await imageReopened.recover()
        expectEqual(try await imageReopened.load().map(\.id), [replacement.id])
        expectEqual(try files(imageRoot).count, 2)
    }
    private func files(_ root: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Images").path)
    }
    private func sql(_ root: URL, _ query: String) throws {
        var connection: OpaquePointer?
        expectEqual(sqlite3_open(root.appendingPathComponent("history.sqlite").path, &connection), SQLITE_OK)
        defer { sqlite3_close(connection) }
        expectEqual(sqlite3_exec(connection, query, nil, nil, nil), SQLITE_OK)
    }
    private func imageData(red: UInt8, type: NSBitmapImageRep.FileType, width: Int = 16, alpha: UInt8 = 255) throws -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: 12, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<12 {
            for x in 0..<width {
                let p = bitmap.bitmapData! + y * bitmap.bytesPerRow + x * 4
                p[0] = red; p[1] = 80; p[2] = 100; p[3] = alpha
            }
        }
        return try unwrap(bitmap.representation(using: type, properties: [:]))
    }
}
