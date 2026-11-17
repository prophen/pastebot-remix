import Foundation
import AppKit
import UniformTypeIdentifiers

/// Independent copies for drag handoff, never URLs into the retained history.
/// Concrete file URLs support browser upload targets as well as document apps.
public actor PNGDragExportStore {
    public static let shared = PNGDragExportStore(
        root: URL(fileURLWithPath: "/Volumes/Expansion/pastebot-remix-build/DragExports", isDirectory: true),
        requiredVolume: URL(fileURLWithPath: "/Volumes/Expansion", isDirectory: true)
    )
    public nonisolated let root: URL
    private let retention: TimeInterval
    private let requiredVolume: URL?
    private var active: Set<String> = []
    private let marker = ".clipboard-remix-export"

    /// The parent must already exist: never create a missing volume mount path.
    public init(root: URL, retention: TimeInterval = 7 * 24 * 60 * 60, requiredVolume: URL? = nil) {
        self.root = root
        self.retention = retention
        self.requiredVolume = requiredVolume
    }

    public func export(_ png: Data, now: Date = Date()) throws -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.deletingLastPathComponent().path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw HistoryError.message("Mount Expansion before dragging an image; the export folder is unavailable.")
        }
        if let requiredVolume {
            let actualVolume = try root.deletingLastPathComponent().resourceValues(forKeys: [.volumeURLKey]).volume
            guard actualVolume?.standardizedFileURL.path == requiredVolume.standardizedFileURL.path else {
                throw HistoryError.message("Mount Expansion before dragging an image; the export volume is unavailable.")
            }
        }
        guard png.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
            throw HistoryError.message("Cannot export this image as PNG.")
        }
        var rootIsDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: root.path, isDirectory: &rootIsDirectory) {
            guard rootIsDirectory.boolValue else { throw HistoryError.message("The image export location is not a folder.") }
        } else {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        try cleanup(now: now)
        let folder = root.appendingPathComponent("drag-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let file = folder.appendingPathComponent("Clipboard-Remix.png")
        do {
            try png.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            try Data("ClipboardRemix PNG export v1".utf8).write(to: folder.appendingPathComponent(marker), options: .atomic)
            try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: folder.path)
            active.insert(folder.standardizedFileURL.path)
            return file
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// End the producer request; keep the snapshot for the full retention period.
    public func finish(_ file: URL, now: Date = Date()) {
        let folder = file.deletingLastPathComponent()
        active.remove(folder.standardizedFileURL.path)
        // Give receivers a full grace period after the preview/drag releases its
        // lease, even if the preview was open for longer than the retention age.
        try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: folder.path)
    }

    /// Called on exports. Only our marked, inactive, seven-day-old directories
    /// are removed. A completed/cancelled drag never triggers deletion.
    public func cleanup(now: Date = Date()) throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        let folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
        for folder in folders where folder.lastPathComponent.hasPrefix("drag-") && !active.contains(folder.standardizedFileURL.path) {
            guard UUID(uuidString: String(folder.lastPathComponent.dropFirst(5))) != nil else { continue }
            let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate, now.timeIntervalSince(modified) >= retention,
                  (try? Data(contentsOf: folder.appendingPathComponent(marker))) == Data("ClipboardRemix PNG export v1".utf8) else { continue }
            try FileManager.default.removeItem(at: folder)
        }
    }
}


/// Owns a concrete export for the entire preview/drag lifetime. Browser upload
/// targets discover a file URL on the dragging pasteboard, as with Finder.
public final class PNGDragSnapshot: NSObject, NSPasteboardWriting {
    public let file: URL
    public let png: Data
    private let exports: PNGDragExportStore
    public init(file: URL, png: Data, exports: PNGDragExportStore) {
        self.file = file; self.png = png; self.exports = exports
    }
    deinit {
        let file = file, exports = exports
        Task { await exports.finish(file) }
    }
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.fileURL, .png]
    }
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL: return file.absoluteString
        case .png: return png
        default: return nil
        }
    }
}

public enum PNGDragProvider {
    public static func prepare(png: Data, exports: PNGDragExportStore = .shared) async throws -> PNGDragSnapshot {
        let file = try await exports.export(png)
        return PNGDragSnapshot(file: file, png: png, exports: exports)
    }
}
