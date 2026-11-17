import Foundation

public enum ClipKind: String, Codable, Sendable { case text, image }
public enum ClipFilter: String, CaseIterable, Sendable { case all = "All", text = "Text", images = "Images" }
public struct HistoryItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: ClipKind
    public let created: Date
    public let text: String?
    public let imagePath: String?
    public let thumbnailPath: String?
    public let width: Int
    public let height: Int
    public let bytes: Int
    public var isPinned: Bool = false
    public var title: String { text.map { String($0.prefix(160)).replacingOccurrences(of: "\n", with: " ") } ?? "Image · \(width) × \(height)" }
    public static func matching(_ items: [Self], query: String, filter: ClipFilter) -> [Self] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter {
            (filter == .all || (filter == .text && $0.kind == .text) || (filter == .images && $0.kind == .image)) &&
            (query.isEmpty || ($0.text?.localizedStandardContains(query) ?? false))
        }
    }
}
public enum CapturePayload: Sendable { case text(String), image(Data) }
public enum HistoryError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

/// Tracking change counts also suppresses our writes without suppressing future identical copies.
public struct ClipboardChangeTracker {
    public private(set) var last: Int
    public init(initial: Int) { last = initial }
    public mutating func consume(_ count: Int) -> Bool {
        guard count != last else { return false }; last = count; return true
    }
    public mutating func suppress(_ count: Int) { last = count }
}
