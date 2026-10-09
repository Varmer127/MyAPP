import Foundation
import SwiftData

/// One commitment. Named TaskItem to avoid clashing with Swift concurrency's `Task`.
@Model
final class TaskItem {
    var uid: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = TaskCategory.other.rawValue
    var priorityRaw: String = TaskPriority.medium.rawValue
    /// Points this task is worth (1–5).
    var weight: Int = 1
    var plannedMinutes: Int = 30
    var notes: String = ""
    /// "Why does this matter?" — reused later to confront the user with their own motivation.
    var why: String = ""
    /// Start of the day the task is currently scheduled on.
    var scheduledDate: Date = Date()
    /// Optional exact deadline. Without it the task is due by the end of `scheduledDate`.
    var deadline: Date?
    var requiresProof: Bool = false
    var usesFocus: Bool = false
    var statusRaw: String = TaskStatus.pending.rawValue
    var completedAt: Date?
    var createdAt: Date = Date()

    // Commitment tracking. Set once when the week is committed and never lowered afterwards.
    var isCommitted: Bool = false
    var originalDate: Date?
    var originalWeight: Int = 0
    var originalPriorityRaw: String?
    var editedAfterCommitment: Bool = false
    /// Soft delete: a committed task can never really disappear.
    var isRemoved: Bool = false
    var removedAt: Date?
    var moveCount: Int = 0
    var isRecovery: Bool = false

    /// What was trained, for gym tasks. Empty until the workout is logged.
    var workoutType: String = ""
    var workoutAbs: Bool = false
    /// Body weight in kg logged with the workout, if any.
    var bodyWeight: Double?
    /// Main lift of the workout, to follow strength over time.
    var liftName: String = ""
    var liftWeight: Double?
    var liftReps: Int = 0

    /// What the user bet on this task: the consequence they accept if it is not done.
    var stake: String = ""
    /// 0 = not answered yet, 1 = the stake was honoured after failing, 2 = it was not.
    var stakeOutcome: Int = 0

    /// How much of the task was really done (0...1). Below 1 the task counts as partially completed.
    var completionShare: Double = 1
    var partialNote: String = ""

    /// Proof of completion, for tasks that require it.
    var proofNote: String = ""
    @Attribute(.externalStorage) var proofPhoto: Data?

    var plan: WeeklyPlan?
    @Relationship(deleteRule: .cascade, inverse: \FailureRecord.task)
    var failures: [FailureRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \FocusSession.task)
    var focusSessions: [FocusSession] = []
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.task)
    var exercises: [ExerciseLog] = []

    init(title: String, category: TaskCategory, priority: TaskPriority, weight: Int, scheduledDate: Date) {
        self.title = title
        self.categoryRaw = category.rawValue
        self.priorityRaw = priority.rawValue
        self.weight = weight
        self.scheduledDate = scheduledDate.startOfDay
    }

    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var originalPriority: TaskPriority? {
        originalPriorityRaw.flatMap(TaskPriority.init(rawValue:))
    }

    /// "Nohy + břicho"
    var workoutSummary: String? {
        guard !workoutType.isEmpty else { return nil }
        var parts = [workoutAbs ? "\(workoutType) + břicho" : workoutType]
        if let bodyWeight {
            parts.append(bodyWeight.kilogramText)
        }
        return parts.joined(separator: " · ")
    }

    /// Lowering weight or priority after committing must not make a failure cheaper.
    var scoringWeight: Int { isCommitted ? max(weight, originalWeight) : weight }

    var scoringPriority: TaskPriority {
        guard let original = originalPriority, original.rank > priority.rank else { return priority }
        return original
    }

    var isAddedAfterCommitment: Bool { !isCommitted && !isRecovery && plan?.isCommitted == true }

    /// The focus session that was started and not yet ended, if any.
    /// Relationship arrays have no stable order, so "the" running session is always the most recently started one.
    var activeFocusSession: FocusSession? {
        focusSessions.filter { !$0.isFinished }.max { $0.startedAt < $1.startedAt }
    }

    /// Returns the running session, starting one only if there is none.
    @discardableResult
    func startFocusIfNeeded(in context: ModelContext, now: Date = .now) -> FocusSession {
        if let running = activeFocusSession { return running }
        let session = FocusSession(task: self, now: now)
        context.insert(session)
        try? context.save()
        return session
    }

    func finishFocusSessions(at now: Date = .now) {
        for session in focusSessions where !session.isFinished {
            session.finish(at: now)
        }
    }

    var dueDate: Date { deadline ?? scheduledDate.endOfDay }

    var isDone: Bool { !isRemoved && (status == .completed || status == .completedLate) }

    /// Done, but only in part.
    var isPartial: Bool { isDone && completionShare < 1 }
    var isFullyDone: Bool { isDone && completionShare >= 1 }
    /// What the task counts for as a kept promise: 0 if not done, otherwise the completed share.
    var keptShare: Double { isDone ? min(max(completionShare, 0), 1) : 0 }

    func dayHasPassed(_ now: Date) -> Bool { now >= scheduledDate.endOfDay }

    /// Past its deadline (or day) and still open.
    func isOverdue(_ now: Date) -> Bool { status == .pending && !isRemoved && now > dueDate }

    /// The day ended and the task was neither done nor explained.
    func isMissed(_ now: Date) -> Bool { status == .pending && !isRemoved && dayHasPassed(now) }

    /// Outcome is final for scoring purposes.
    func isClosed(_ now: Date) -> Bool { isRemoved || status != .pending || dayHasPassed(now) }

    /// Closed without being done.
    func isLost(_ now: Date) -> Bool { isClosed(now) && !isDone }

    /// Share of the task's weight that was earned (0...1).
    var completionFactor: Double {
        guard isDone else { return 0 }
        guard status == .completedLate, let completedAt else { return keptShare }
        return keptShare * ScoreEngine.lateFactor(delay: completedAt.timeIntervalSince(dueDate))
    }

    func markDone(at now: Date = .now) {
        // The timer ends here, when the task is really done — not when the user merely taps DONE
        // and may still cancel the proof or workout sheet.
        finishFocusSessions(at: now)
        completedAt = now
        status = now > dueDate ? .completedLate : .completed
    }

    /// Takes back a completion, skip or failure and makes the task open again.
    /// What was logged with the completion goes with it, so re-completing does not duplicate it.
    /// Failure records stay: an excuse that was written remains part of the history.
    func reopen() {
        completedAt = nil
        completionShare = 1
        partialNote = ""
        workoutType = ""
        workoutAbs = false
        bodyWeight = nil
        proofNote = ""
        proofPhoto = nil
        stakeOutcome = 0
        for exercise in exercises {
            modelContext?.delete(exercise)
        }
        status = .pending
    }

    /// A done task can always be taken back; a skip or failure only on the day itself,
    /// so old failures cannot be quietly erased later.
    func canReopen(now: Date = .now) -> Bool {
        guard !isRemoved, status != .pending else { return false }
        return isDone || !dayHasPassed(now)
    }
}
