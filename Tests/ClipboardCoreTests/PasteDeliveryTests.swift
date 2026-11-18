import ClipboardCore

@MainActor final class PasteDeliveryTests {
    func testWaitsForStableFocus() async throws {
        // Chromium may expose web focus only after a two-second AX startup.
        for readyAt in [2, 40] {
            var ticks = 0, sends = 0
            try await PasteDelivery.deliver(isCurrent: { true }, destinationExists: { true }, clipboardUnchanged: { true }, destinationReady: { ticks >= readyAt }, send: { sends += 1 }, wait: { ticks += 1 }, attempts: 80)
            expectEqual(sends, 1)
            expectEqual(ticks, readyAt + 2)
        }
    }
    func testNeverSendsAfterCancellationOrClipboardChange() async throws {
        for reason in [PasteDelivery.Failure.cancelled, .destinationUnavailable, .clipboardChanged] {
            var ticks = 0, sends = 0
            do {
                try await PasteDelivery.deliver(
                    isCurrent: { reason != .cancelled || ticks == 0 },
                    destinationExists: { reason != .destinationUnavailable || ticks == 0 },
                    clipboardUnchanged: { reason != .clipboardChanged || ticks == 0 },
                    destinationReady: { true }, send: { sends += 1 }, wait: { ticks += 1 })
                fail("Expected paste delivery to stop")
            } catch let error as PasteDelivery.Failure { expectEqual(error, reason) }
            expectEqual(sends, 0)
        }
    }
    func testUnstableOrMissingFocusTimesOut() async throws {
        for unstable in [false, true] {
            var ticks = 0, sends = 0
            do {
                try await PasteDelivery.deliver(isCurrent: { true }, destinationExists: { true }, clipboardUnchanged: { true }, destinationReady: { unstable && ticks % 2 == 0 }, send: { sends += 1 }, wait: { ticks += 1 }, attempts: 8)
                fail("Expected timeout")
            } catch let error as PasteDelivery.Failure { expectEqual(error, .timedOut) }
            expectEqual(sends, 0)
        }
    }
}
