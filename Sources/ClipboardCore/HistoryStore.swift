import Foundation
import CSQLite
import ImageIO
import UniformTypeIdentifiers

/// All database and file operations are serialized away from the main actor.
public actor HistoryStore {
    public nonisolated let root: URL
    private var db: OpaquePointer?
    private let images: ImageStore
    private var maxItems: Int
    private var maxBytes: Int
    public init(root: URL, maxItems: Int = 500, maxBytes: Int = 500_000_000) throws {
        self.root = root; self.maxItems = maxItems; self.maxBytes = maxBytes
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        images = try ImageStore(root: root)
        var connection: OpaquePointer?
        guard sqlite3_open(root.appendingPathComponent("history.sqlite").path, &connection) == SQLITE_OK else {
            sqlite3_close(connection); throw HistoryError.message("Cannot open history database.")
        }
        db = connection
        let schema = "PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS clips (id TEXT PRIMARY KEY, kind TEXT NOT NULL, created REAL NOT NULL, text TEXT, image TEXT, thumbnail TEXT, width INTEGER NOT NULL, height INTEGER NOT NULL, bytes INTEGER NOT NULL);"
        guard sqlite3_exec(connection, schema, nil, nil, nil) == SQLITE_OK else {
            sqlite3_close(connection); db = nil; throw HistoryError.message("Cannot initialize history database.")
        }
        // Probe the column rather than assuming a schema version from older builds.
        var probe: OpaquePointer?
        let hasPins = sqlite3_prepare_v2(connection, "SELECT pinned FROM clips LIMIT 0", -1, &probe, nil) == SQLITE_OK
        sqlite3_finalize(probe)
        if !hasPins {
            guard sqlite3_exec(connection, "ALTER TABLE clips ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0", nil, nil, nil) == SQLITE_OK else {
                sqlite3_close(connection); db = nil
                throw HistoryError.message("Cannot migrate favorite clips.")
            }
        }
    }
    deinit { sqlite3_close(db) }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw failure() }
        return stmt
    }
    private func failure() -> HistoryError { .message(String(cString: sqlite3_errmsg(db))) }
    private func bind(_ string: String?, to stmt: OpaquePointer, at index: Int32) {
        if let string { string.withCString { ptr in _ = sqlite3_bind_text(stmt, index, ptr, Int32(string.utf8.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) } }
        else { sqlite3_bind_null(stmt, index) }
    }
    public func load() throws -> [HistoryItem] {
        let stmt = try statement("SELECT id,kind,created,text,image,thumbnail,width,height,bytes,pinned FROM clips ORDER BY pinned DESC, created DESC, rowid DESC")
        defer { sqlite3_finalize(stmt) }
        func value(_ index: Int32) -> String? {
            guard let p = sqlite3_column_text(stmt, index) else { return nil }
            return String(decoding: UnsafeBufferPointer(start: p, count: Int(sqlite3_column_bytes(stmt, index))), as: UTF8.self)
        }
        var result: [HistoryItem] = []
        var status = sqlite3_step(stmt)
        while status == SQLITE_ROW {
            if let id = value(0), let kind = value(1).flatMap(ClipKind.init(rawValue:)) {
                result.append(HistoryItem(id: id, kind: kind, created: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)), text: value(3), imagePath: value(4), thumbnailPath: value(5), width: Int(sqlite3_column_int(stmt, 6)), height: Int(sqlite3_column_int(stmt, 7)), bytes: Int(sqlite3_column_int64(stmt, 8)), isPinned: sqlite3_column_int(stmt, 9) != 0))
            }
            status = sqlite3_step(stmt)
        }
        guard status == SQLITE_DONE else { throw failure() }; return result
    }
    @discardableResult public func capture(_ payload: CapturePayload) throws -> HistoryItem {
        let pins = try load().filter(\.isPinned)
        guard pins.count < maxItems else {
            throw HistoryError.message("Capture skipped: favorites fill the item limit. Unpin or delete a favorite.")
        }
        let pinnedBytes = pins.filter { $0.kind == .image }.reduce(0) { $0 + $1.bytes }
        let id = UUID().uuidString
        let item: HistoryItem
        switch payload {
        case .text(let text):
            guard text.utf8.count <= 2_000_000 else { throw HistoryError.message("Text skipped: exceeds 2 MB per item.") }
            item = HistoryItem(id: id, kind: .text, created: Date(), text: text, imagePath: nil, thumbnailPath: nil, width: 0, height: 0, bytes: text.utf8.count)
        case .image(let data):
            let (path, thumb, width, height, bytes) = try images.write(data, id: id, limit: maxBytes)
            item = HistoryItem(id: id, kind: .image, created: Date(), text: nil, imagePath: path, thumbnailPath: thumb, width: width, height: height, bytes: bytes)
        }
        do {
            if item.kind == .image && pinnedBytes + item.bytes > maxBytes {
                throw HistoryError.message("Image skipped: favorites leave insufficient image storage. Unpin or delete a favorite.")
            }
            let stmt = try statement("INSERT INTO clips (id,kind,created,text,image,thumbnail,width,height,bytes) VALUES (?,?,?,?,?,?,?,?,?)")
            defer { sqlite3_finalize(stmt) }
            bind(item.id, to: stmt, at: 1); bind(item.kind.rawValue, to: stmt, at: 2)
            sqlite3_bind_double(stmt, 3, item.created.timeIntervalSince1970)
            bind(item.text, to: stmt, at: 4); bind(item.imagePath, to: stmt, at: 5); bind(item.thumbnailPath, to: stmt, at: 6)
            sqlite3_bind_int(stmt, 7, Int32(item.width)); sqlite3_bind_int(stmt, 8, Int32(item.height)); sqlite3_bind_int64(stmt, 9, Int64(item.bytes))
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
        } catch { images.remove(item.imagePath); images.remove(item.thumbnailPath); throw error }
        try enforceLimits(); return item
    }
    public func delete(_ id: String) throws {
        guard let item = try load().first(where: { $0.id == id }) else { return }
        let stmt = try statement("DELETE FROM clips WHERE id = ?")
        defer { sqlite3_finalize(stmt) }; bind(id, to: stmt, at: 1)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
        images.remove(item.imagePath); images.remove(item.thumbnailPath)
    }
    public func setPinned(_ id: String, pinned: Bool) throws {
        let stmt = try statement("UPDATE clips SET pinned = ? WHERE id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, pinned ? 1 : 0); bind(id, to: stmt, at: 2)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
        try enforceLimits()
    }
    public func clear() throws { for item in try load() { try delete(item.id) }; sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE); VACUUM;", nil, nil, nil) }
    public func setLimits(items: Int, bytes: Int) throws {
        maxItems = max(1, items); maxBytes = max(1, bytes); try enforceLimits()
    }
    private func enforceLimits() throws {
        var items = try load()
        var bytes = items.filter { $0.kind == .image }.reduce(0) { $0 + $1.bytes }
        while items.count > maxItems || bytes > maxBytes {
            guard let index = items.lastIndex(where: { !$0.isPinned }) else { break }
            let item = items.remove(at: index)
            try delete(item.id); if item.kind == .image { bytes -= item.bytes }
        }
    }
    public func recover() throws {
        for item in try load() where item.kind == .image {
            if !images.exists(item.imagePath) || !images.exists(item.thumbnailPath) { try delete(item.id) }
        }
        let referenced = Set(try load().flatMap { [$0.imagePath, $0.thumbnailPath].compactMap { $0 } })
        for url in try FileManager.default.contentsOfDirectory(at: images.directory, includingPropertiesForKeys: nil) where !referenced.contains(url.lastPathComponent) { try FileManager.default.removeItem(at: url) }
        try enforceLimits()
    }
    public func imageData(for item: HistoryItem, thumbnail: Bool = false) throws -> Data {
        guard let path = thumbnail ? item.thumbnailPath : item.imagePath else { throw HistoryError.message("No image file.") }
        return try Data(contentsOf: images.directory.appendingPathComponent(path))
    }
    public func previewData(for item: HistoryItem) throws -> Data {
        guard let path = item.imagePath,
              let source = CGImageSourceCreateWithURL(images.directory.appendingPathComponent(path) as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1600, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else {
            throw HistoryError.message("Image unavailable.")
        }
        return try encode(image, type: UTType.png.identifier)
    }
    public func clipboardImage(for item: HistoryItem) throws -> (png: Data, tiff: Data) {
        let png = try imageData(for: item)
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw HistoryError.message("Image unavailable.") }
        return (png, try encode(image, type: UTType.tiff.identifier))
    }
    private func encode(_ image: CGImage, type: String) throws -> Data {
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, type as CFString, 1, nil) else { throw HistoryError.message("Cannot prepare image.") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw HistoryError.message("Cannot prepare image.") }
        return result as Data
    }

}
