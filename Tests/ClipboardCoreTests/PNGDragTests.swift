import Foundation
import UniformTypeIdentifiers
import ClipboardCore

@MainActor final class PNGDragTests {
    func testProviderSnapshotAndRepresentations() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("drag-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let history = try HistoryStore(root: root.appendingPathComponent("History"))
        let clip = try await history.capture(.image(HistoryStoreTests().png()))
        let png = try await history.imageData(for: clip)
        let exports = PNGDragExportStore(root: root.appendingPathComponent("Exports"))
        let provider = PNGDragProvider.make(png: png, exports: exports)
        expectTrue(provider.hasItemConformingToTypeIdentifier(UTType.png.identifier))
        expectTrue(provider.hasItemConformingToTypeIdentifier(UTType.image.identifier))
        expectEqual(provider.suggestedName, "Clipboard-Remix.png")
        // Merely starting/cancelling a drag creates no file and changes no history.
        expectFalse(FileManager.default.fileExists(atPath: exports.root.path))
        expectEqual(try await history.load().map(\.id), [clip.id])
        // The provider owns a snapshot; subsequent real history eviction cannot
        // invalidate a receiving app's request (only this disposable fixture is deleted).
        try await history.delete(clip.id)
        let data = try await loadData(provider)
        expectEqual(data, png)
        let receivedFileData = try await loadFileBytes(provider)
        expectEqual(receivedFileData, png)
        expectTrue(try await history.load().isEmpty)
    }

    func testExportRetentionAndMissingVolume() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("drag-retention-" + UUID().uuidString)
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

    private func loadData(_ provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? CheckError.nilValue) }
            }
        }
    }
    private func loadFileBytes(_ provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: UTType.png.identifier) { url, error in
                // The consumer must use/copy the system's file before returning.
                guard let url else { continuation.resume(throwing: error ?? CheckError.nilValue); return }
                do { continuation.resume(returning: try Data(contentsOf: url)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}
