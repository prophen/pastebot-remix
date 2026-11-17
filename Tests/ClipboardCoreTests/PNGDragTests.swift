import Foundation
import AppKit
import UniformTypeIdentifiers
import ClipboardCore

@MainActor final class PNGDragTests {
    func testProviderSnapshotAndRepresentations() async throws {
        let root = checkTemporaryDirectory.appendingPathComponent("drag-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let history = try HistoryStore(root: root.appendingPathComponent("History"))
        let clip = try await history.capture(.image(HistoryStoreTests().png()))
        let png = try await history.imageData(for: clip)
        let exports = PNGDragExportStore(root: root.appendingPathComponent("Exports"))
        let snapshot = try await PNGDragProvider.prepare(png: png, exports: exports)
        let board = NSPasteboard(name: .init("ClipboardRemix.DragChecks.\(UUID())"))
        defer { board.releaseGlobally() }
        expectTrue(board.writeObjects([snapshot]))
        expectTrue(board.types?.contains(.fileURL) == true)
        expectEqual(board.data(forType: .png), png)
        let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        expectEqual(files, [snapshot.file])
        expectEqual(snapshot.file.pathExtension, "png")
        expectEqual(try await history.load().map(\.id), [clip.id])
        // A concrete file remains readable throughout a drag and after fixture
        // history deletion. This is the file representation browser uploads need.
        try await history.delete(clip.id)
        expectEqual(try Data(contentsOf: snapshot.file), png)
        try await exports.cleanup(now: Date().addingTimeInterval(8 * 24 * 60 * 60))
        expectEqual(try Data(contentsOf: snapshot.file), png)
        expectTrue(try await history.load().isEmpty)
    }

    func testExportRetentionAndMissingVolume() async throws {
        let root = checkTemporaryDirectory.appendingPathComponent("drag-retention-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let exports = PNGDragExportStore(root: root.appendingPathComponent("Exports"), retention: 60)
        let png = try HistoryStoreTests().png()
        let now = Date()
        let file = try await exports.export(png, now: now)
        expectEqual(try Data(contentsOf: file), png)
        // Active provider requests are protected even beyond the normal expiry.
        try await exports.cleanup(now: now.addingTimeInterval(120))
        expectTrue(FileManager.default.fileExists(atPath: file.path))
        await exports.finish(file)
        // Completion/cancellation does not remove the producer snapshot.
        expectTrue(FileManager.default.fileExists(atPath: file.path))
        try await exports.cleanup(now: now.addingTimeInterval(30))
        expectTrue(FileManager.default.fileExists(atPath: file.path))
        let unrelated = exports.root.appendingPathComponent("leave-this-alone.txt")
        try Data([1]).write(to: unrelated)
        let unknown = exports.root.appendingPathComponent("drag-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: unknown, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-500)], ofItemAtPath: unknown.path)
        try await exports.cleanup(now: now.addingTimeInterval(120))
        expectFalse(FileManager.default.fileExists(atPath: file.path))
        expectTrue(FileManager.default.fileExists(atPath: unrelated.path))
        expectTrue(FileManager.default.fileExists(atPath: unknown.path))
        // A preview may remain selected beyond retention before the user drags.
        // Its release must start a fresh grace period for the receiver.
        let aged = try await exports.export(png, now: now.addingTimeInterval(-600))
        try await exports.cleanup(now: now)
        expectTrue(FileManager.default.fileExists(atPath: aged.path))
        await exports.finish(aged, now: now)
        try await exports.cleanup(now: now.addingTimeInterval(30))
        expectTrue(FileManager.default.fileExists(atPath: aged.path))
        try await exports.cleanup(now: now.addingTimeInterval(120))
        expectFalse(FileManager.default.fileExists(atPath: aged.path))
        let actualVolume = try unwrap(root.resourceValues(forKeys: [.volumeURLKey]).volume)
        let onVolume = PNGDragExportStore(root: root.appendingPathComponent("CheckedVolume"), requiredVolume: actualVolume)
        let onVolumeFile = try await onVolume.export(png)
        expectEqual(try Data(contentsOf: onVolumeFile), png)
        await onVolume.finish(onVolumeFile)
        let wrongVolume = PNGDragExportStore(root: root.appendingPathComponent("WrongVolume"), requiredVolume: URL(fileURLWithPath: "/Volumes/not-the-build-volume"))
        do { _ = try await wrongVolume.export(png); fail("Must reject a mismatched volume") } catch {}
        expectFalse(FileManager.default.fileExists(atPath: wrongVolume.root.path))
        let unavailableRoot = root.appendingPathComponent("unmounted/build/Exports")
        let unavailable = PNGDragExportStore(root: unavailableRoot)
        do { _ = try await unavailable.export(png); fail("Must not create a missing mount path") } catch {}
        expectFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("unmounted").path))
    }

}
