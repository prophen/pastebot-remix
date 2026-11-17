import Foundation

/// An expiry can only remove the message it was scheduled for, never a newer one.
public struct BriefFeedback {
    public private(set) var message: String?
    public private(set) var expiresAt: Date?
    private var currentID: UUID?
    public init() {}
    @discardableResult public mutating func show(_ message: String, at now: Date, duration: TimeInterval = 2) -> UUID {
        let id = UUID()
        currentID = id
        self.message = message
        expiresAt = now.addingTimeInterval(max(0, duration))
        return id
    }
    @discardableResult public mutating func expire(_ id: UUID, at now: Date) -> Bool {
        guard currentID == id, let expiresAt, now >= expiresAt else { return false }
        clear()
        return true
    }
    public mutating func clear() {
        currentID = nil
        message = nil
        expiresAt = nil
    }
}
