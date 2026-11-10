import Foundation
import SwiftData

/// One run of the focus timer. Time is derived from stored timestamps, never from a running
/// counter, so the session stays correct when the app is suspended or killed mid-focus.
@Model
final class FocusSession {
    var startedAt: Date = Date()
    var endedAt: Date?
    var plannedMinutes: Int = 0
    /// Focused time accumulated up to the last pause.
    var activeSeconds: Double = 0
    /// Paused time accumulated up to the last resume.
    var pauseSeconds: Double = 0
    var pauseCount: Int = 0
    /// Set while the timer is running.
    var runningSince: Date?
    /// Set while the timer is paused. In a workout this is a rest between sets.
    var pausedSince: Date?
    /// Set while a workout's clock is stopped altogether (a call, a queue for a machine): neither training nor rest.
    var heldSince: Date?
    /// Stopped time accumulated up to the last restart. Not part of the workout's time.
    var heldSeconds: Double = 0
    var task: TaskItem?

    init(task: TaskItem, now: Date = .now) {
        self.startedAt = now
        self.plannedMinutes = task.plannedMinutes
        self.runningSince = now
        self.task = task
    }

    var isFinished: Bool { endedAt != nil }
    var isPaused: Bool { pausedSince != nil }
    var isHeld: Bool { heldSince != nil }

    func active(at now: Date = .now) -> TimeInterval {
        activeSeconds + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    func paused(at now: Date = .now) -> TimeInterval {
        pauseSeconds + (pausedSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    func remaining(at now: Date = .now) -> TimeInterval {
        TimeInterval(plannedMinutes * 60) - active(at: now)
    }

    func pause(at now: Date = .now) {
        guard let runningSince else { return }
        activeSeconds += now.timeIntervalSince(runningSince)
        self.runningSince = nil
        pausedSince = now
        pauseCount += 1
        persist()
    }

    func resume(at now: Date = .now) {
        guard let pausedSince else { return }
        pauseSeconds += now.timeIntervalSince(pausedSince)
        self.pausedSince = nil
        runningSince = now
        persist()
    }

    /// Stops the clock without ending the session; a rest in progress ends with it.
    func hold(at now: Date = .now) {
        guard heldSince == nil else { return }
        if let runningSince {
            activeSeconds += now.timeIntervalSince(runningSince)
            self.runningSince = nil
        }
        if let pausedSince {
            pauseSeconds += now.timeIntervalSince(pausedSince)
            self.pausedSince = nil
        }
        heldSince = now
        persist()
    }

    /// Starts the stopped clock again where it was.
    func unhold(at now: Date = .now) {
        guard let heldSince else { return }
        heldSeconds += now.timeIntervalSince(heldSince)
        self.heldSince = nil
        runningSince = now
        persist()
    }

    func finish(at now: Date = .now) {
        if let heldSince {
            heldSeconds += now.timeIntervalSince(heldSince)
            self.heldSince = nil
        }
        activeSeconds = active(at: now)
        pauseSeconds = paused(at: now)
        runningSince = nil
        pausedSince = nil
        endedAt = now
        persist()
    }

    /// SwiftData saves on its own schedule; a timer must be on disk the moment it changes,
    /// otherwise force-quitting the app right after starting or pausing would lose that state.
    func persist() {
        Persistence.save(modelContext)
    }

    /// Ends sessions that were left running on a task that is no longer open today.
    /// A forgotten timer is not focus, so it counts for the planned time at most.
    static func closeAbandoned(in tasks: [TaskItem], now: Date = .now) {
        for task in tasks {
            guard let session = task.activeFocusSession,
                  task.status != .pending || task.isRemoved || task.dayHasPassed(now) else { continue }
            session.finish(at: min(now, max(task.scheduledDate.endOfDay, session.startedAt)))
            session.activeSeconds = min(session.activeSeconds, Double(session.plannedMinutes * 60))
        }
    }
}
