import Foundation
import ClipboardCore

func testTimedPauseAndFeedbackState() {
    let start = Date(timeIntervalSince1970: 1_000)
    var pause = CapturePause()
    expectFalse(pause.isPaused)
    pause.pause(until: start.addingTimeInterval(900))
    expectTrue(pause.isPaused)
    expectFalse(pause.expire(at: start.addingTimeInterval(899)))
    expectTrue(pause.expire(at: start.addingTimeInterval(900)))
    expectFalse(pause.isPaused)
    expectEqual(pause.resumeAt, nil)
    pause.pause(until: start.addingTimeInterval(900))
    expectTrue(pause.expire(at: start.addingTimeInterval(3_600))) // wake after deadline
    pause.pause(until: start.addingTimeInterval(900))
    pause.resume()
    expectFalse(pause.expire(at: start.addingTimeInterval(3_600)))
    expectEqual(pause.resumeAt, nil)
    pause.pause(until: start.addingTimeInterval(900))
    pause.pause() // switch to indefinite; old timer cannot resume it
    expectFalse(pause.expire(at: start.addingTimeInterval(3_600)))
    expectTrue(pause.isPaused)
    expectEqual(pause.resumeAt, nil)
    pause.resume()
    expectFalse(pause.isPaused)
    expectFalse(CapturePause().isPaused) // relaunch policy

    var feedback = BriefFeedback()
    let first = feedback.show("Copied", at: start)
    expectFalse(feedback.expire(first, at: start.addingTimeInterval(1)))
    let second = feedback.show("Paste sent to TextEdit", at: start.addingTimeInterval(1))
    expectFalse(feedback.expire(first, at: start.addingTimeInterval(3)))
    expectEqual(feedback.message, "Paste sent to TextEdit")
    expectTrue(feedback.expire(second, at: start.addingTimeInterval(3)))
    expectEqual(feedback.message, nil)
    let third = feedback.show("Copied", at: start)
    feedback.clear()
    let fourth = feedback.show("Copied", at: start.addingTimeInterval(1))
    expectFalse(feedback.expire(third, at: start.addingTimeInterval(3)))
    expectTrue(feedback.expire(fourth, at: start.addingTimeInterval(3)))
}
