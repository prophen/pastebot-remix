import Foundation

/// Waits for the destination to regain focus. All checks run again immediately
/// before sending; cancellation or another clipboard write must never paste stale data.
@MainActor public enum PasteDelivery {
    public enum Failure: Error, Equatable { case cancelled, destinationUnavailable, clipboardChanged, timedOut }
    public static func deliver(
        isCurrent: () -> Bool,
        destinationExists: () -> Bool,
        clipboardUnchanged: () -> Bool,
        destinationReady: () -> Bool,
        send: () -> Void,
        wait: () async throws -> Void = { try await Task.sleep(nanoseconds: 50_000_000) },
        attempts: Int = 20
    ) async throws {
        var readyChecks = 0
        for _ in 0..<attempts {
            guard !Task.isCancelled, isCurrent() else { throw Failure.cancelled }
            guard destinationExists() else { throw Failure.destinationUnavailable }
            guard clipboardUnchanged() else { throw Failure.clipboardChanged }
            readyChecks = destinationReady() ? readyChecks + 1 : 0
            if readyChecks >= 3 { send(); return }
            try await wait()
        }
        throw Failure.timedOut
    }
}
