import Foundation
import UniformTypeIdentifiers

/// Independent copies for drag handoff, never URLs into the retained history.
/// Non-open-in-place item providers let macOS copy these files for the receiver.
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
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
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
    public func finish(_ file: URL) { active.remove(file.deletingLastPathComponent().standardizedFileURL.path) }

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

public enum PNGDragProvider {
    /// Captures immutable PNG bytes at drag start, independent of later history
    /// eviction/deletion. It never reads/writes the system clipboard or pastes.
    public static func make(png: Data, exports: PNGDragExportStore = .shared,
                            onError: @escaping @Sendable (String) -> Void = { _ in }) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = "Clipboard-Remix.png"
        provider.registerFileRepresentation(forTypeIdentifier: UTType.png.identifier, fileOptions: [], visibility: .all) { completion in
            Task {
                do {
                    let file = try await exports.export(png)
                    // Without openInPlace, the framework copies this file before
                    // the completion returns; the receiver owns that copy's life.
                    completion(file, false, nil)
                    await exports.finish(file)
                } catch {
                    onError("Image drag failed: \(error.localizedDescription)")
                    completion(nil, false, error)
                }
            }
            return nil
        }
        provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
            completion(png, nil)
            return nil
        }
        return provider
    }
}
