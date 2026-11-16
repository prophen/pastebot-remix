import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageStore {
    let directory: URL
    init(root: URL) throws {
        directory = root.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func write(_ data: Data, id: String, limit: Int) throws -> (String, String, Int, Int, Int) {
        guard data.count <= limit,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, Double(width) * Double(height) <= 80_000_000,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw HistoryError.message("Image skipped: unreadable, over the storage limit, or larger than 80 megapixels.")
        }
        func png(_ image: CGImage) throws -> Data {
            let output = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw HistoryError.message("Cannot encode image.") }
            CGImageDestinationAddImage(dest, image, nil)
            guard CGImageDestinationFinalize(dest) else { throw HistoryError.message("Cannot encode image.") }
            return output as Data
        }
        let full = try png(image)
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 160, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw HistoryError.message("Cannot create thumbnail.") }
        let thumb = try png(thumbnail)
        guard full.count + thumb.count <= limit else { throw HistoryError.message("Image skipped: exceeds the image storage limit.") }
        let path = "\(id).png", thumbPath = "\(id)-thumb.png"
        do {
            try full.write(to: directory.appendingPathComponent(path), options: .atomic)
            try thumb.write(to: directory.appendingPathComponent(thumbPath), options: .atomic)
        } catch { remove(path); remove(thumbPath); throw error }
        return (path, thumbPath, width, height, full.count + thumb.count)
    }
    func remove(_ path: String?) { if let path { try? FileManager.default.removeItem(at: directory.appendingPathComponent(path)) } }
    func exists(_ path: String?) -> Bool { path.map { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) } ?? false }
}
