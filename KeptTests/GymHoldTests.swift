import Foundation
import Testing
@testable import Kept

struct GymHoldTests {
    /// Time with the clock stopped is neither training nor rest, and the clock goes on where it stood.
    @Test @MainActor func stoppedTimeCountsAsNeither() throws {
        let context = try Fixture.context()
        let task = Fixture.task("Gym", category: .gym)
        context.insert(task)
        let start = Fixture.now
        let session = task.startFocusIfNeeded(in: context, now: start)

        session.hold(at: start.addingTimeInterval(600))
        #expect(session.isHeld)
        #expect(session.active(at: start.addingTimeInterval(1200)) == 600)

        session.unhold(at: start.addingTimeInterval(1500))
        #expect(!session.isHeld)
        #expect(session.active(at: start.addingTimeInterval(1800)) == 900)
        #expect(session.heldSeconds == 900)
    }

    /// Stopping the clock during a rest ends the rest; the rest counts only up to that moment.
    @Test @MainActor func stoppingDuringARestEndsIt() throws {
        let context = try Fixture.context()
        let task = Fixture.task("Gym", category: .gym)
        context.insert(task)
        let start = Fixture.now
        let session = task.startFocusIfNeeded(in: context, now: start)

        session.pause(at: start.addingTimeInterval(300))
        session.hold(at: start.addingTimeInterval(420))
        #expect(!session.isPaused)
        #expect(session.paused(at: start.addingTimeInterval(2000)) == 120)

        session.finish(at: start.addingTimeInterval(1000))
        #expect(session.heldSeconds == 580)
        #expect(session.active() + session.paused() == 420)
    }
}
