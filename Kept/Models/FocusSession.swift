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
    /// Set while the timer is paused.
    var pausedSince: Date?
    var task: TaskItem?

    init(task: TaskItem, now: Date = .now) {
        self.startedAt = now
        self.plannedMinutes = task.plannedMinutes
        self.runningSince = now
        self.task = task
    }

    var isFinished: Bool { endedAt != nil }
    var isPaused: Bool { pausedSince != nil }

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
    }

    func resume(at now: Date = .now) {
        guard let pausedSince else { return }
        pauseSeconds += now.timeIntervalSince(pausedSince)
        self.pausedSince = nil
        runningSince = now
    }

    func finish(at now: Date = .now) {
        activeSeconds = active(at: now)
        pauseSeconds = paused(at: now)
        runningSince = nil
        pausedSince = nil
        endedAt = now
    }
}
