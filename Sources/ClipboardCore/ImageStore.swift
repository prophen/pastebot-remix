import Foundation
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

struct ImageStore {
    struct Normalized {
        let image: CGImage
        let pixels: Data
        let fingerprint: String
        var width: Int { image.width }
        var height: Int { image.height }
    }
    let directory: URL
    init(root: URL) throws {
        directory = root.appendingPathComponent("Images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    /// Equality is dimensions plus native-orientation, 8-bit sRGB premultiplied
    /// RGBA samples. Container metadata/compression and invisible RGB are ignored.
    func normalize(_ data: Data) throws -> Normalized {
        guard data.count <= 500_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, Double(width) * Double(height) <= 80_000_000,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            throw HistoryError.message("Image skipped: unreadable, over 500 MB input, or larger than 80 megapixels.")
        }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let normalized = context.makeImage(), let bytes = context.data else { throw HistoryError.message("Cannot normalize image.") }
        let pixels = Data(bytes: bytes, count: width * height * 4)
        var hasher = SHA256()
        hasher.update(data: Data("rgba8-srgb-premultiplied-v1:\(width):\(height):".utf8))
        hasher.update(data: pixels)
        let fingerprint = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return Normalized(image: normalized, pixels: pixels, fingerprint: fingerprint)
    }
    func write(_ normalized: Normalized, id: String, limit: Int) throws -> (String, String, Int, Int, Int) {
        func png(_ image: CGImage) throws -> Data {
            let output = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { throw HistoryError.message("Cannot encode image.") }
            CGImageDestinationAddImage(dest, image, nil)
            guard CGImageDestinationFinalize(dest) else { throw HistoryError.message("Cannot encode image.") }
            return output as Data
        }
        let full = try png(normalized.image)
        guard let source = CGImageSourceCreateWithData(full as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 160, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { throw HistoryError.message("Cannot create thumbnail.") }
        let thumb = try png(thumbnail)
        guard full.count + thumb.count <= limit else { throw HistoryError.message("Image skipped: exceeds the image storage limit.") }
        let path = "\(id).png", thumbPath = "\(id)-thumb.png"
        do {
            try full.write(to: directory.appendingPathComponent(path), options: .atomic)
            try thumb.write(to: directory.appendingPathComponent(thumbPath), options: .atomic)
        } catch { remove(path); remove(thumbPath); throw error }
        return (path, thumbPath, normalized.width, normalized.height, full.count + thumb.count)
    }
    func remove(_ path: String?) { if let path { try? FileManager.default.removeItem(at: directory.appendingPathComponent(path)) } }
    func exists(_ path: String?) -> Bool { path.map { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) } ?? false }
}
