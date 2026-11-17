import Foundation

// A standalone check executable keeps verification available with Command Line Tools,
// which ship neither XCTest.framework nor the full Xcode test runner.
func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line) { precondition(lhs == rhs, "Expected \(rhs), got \(lhs)", file: file, line: line) }
func expectTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, "Expected true", file: file, line: line) }
func expectFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) { expectTrue(!value, file: file, line: line) }
func expectNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value != nil, "Expected non-nil", file: file, line: line) }
func unwrap<T>(_ value: T?) throws -> T { guard let value else { throw CheckError.nilValue }; return value }
func fail(_ message: String) { fatalError(message) }
enum CheckError: Error { case nilValue }

@main struct Runner {
    @MainActor static func main() async throws {
        let storage = HistoryStoreTests()
        defer { for cleanup in storage.teardown { cleanup() } }
        try await storage.testTextPersistsAndSearchCombinesWithFilter()
        print("PASS mixed persistence and search/filter")
        try await storage.testImagePersistenceDeletionAndRecovery()
        print("PASS image pixels, missing-file and orphan recovery")
        try await storage.testRetentionAndClearRemoveFiles()
        print("PASS retention and clear cleanup")
        try await storage.testOversizeAndInvalidImagesLeaveNoFiles()
        print("PASS invalid and oversized image rejection")
        storage.testOwnWritesAreSuppressedButLaterCopiesAreNot()
        print("PASS change count tracking")
        let monitor = ClipboardMonitorTests()
        try monitor.testTextAndScreenshotRoundTripsSuppressOwnWrites()
        print("PASS text and PNG/TIFF pasteboard round trips")
        monitor.testPauseAndSensitiveMarkers()
        print("PASS pause and sensitive markers")
        let paste = PasteDeliveryTests()
        try await paste.testWaitsForStableFocus()
        try await paste.testNeverSendsAfterCancellationOrClipboardChange()
        try await paste.testUnstableOrMissingFocusTimesOut()
        print("PASS paste delivery focus, cancellation, clipboard changes, and timeout")
        try await storage.testFavoritesMigrationAndRetention()
        print("PASS favorites migration, ordering/filtering, reopen, capacity and file retention")
        testPaletteGeometry()
        print("PASS palette geometry restoration and disconnected display recovery")
        print("All 10 check groups passed.")
    }
}
