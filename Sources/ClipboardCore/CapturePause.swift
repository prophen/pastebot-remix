import Foundation

/// Session-only pause state. Relaunch deliberately starts capture unpaused.
/// Deadlines use wall time so a sleep/wake gap cannot extend a timed pause.
public struct CapturePause: Equatable {
    public private(set) var isPaused = false
    public private(set) var resumeAt: Date?
    public init() {}
    public mutating func pause(until deadline: Date? = nil) {
        isPaused = true
        resumeAt = deadline
    }
    public mutating func resume() {
        isPaused = false
        resumeAt = nil
    }
    @discardableResult public mutating func expire(at now: Date) -> Bool {
        guard isPaused, let resumeAt, now >= resumeAt else { return false }
        resume()
        return true
    }
}
