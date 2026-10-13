import Foundation
import SwiftData

@Model
final class WeeklyPlan {
    /// Monday 00:00 of the week.
    var weekStart: Date = Date()
    /// Set when the plan is sealed. Nil while the plan is a draft or still waiting to be sealed.
    var committedAt: Date?
    /// When the user handed the plan in. It is sealed by itself an hour later; until then it can be changed freely.
    var submittedAt: Date?
    /// JSON-encoded `[TaskSnapshot]`: the complete plan exactly as it was committed.
    var snapshotData: Data?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.plan)
    var tasks: [TaskItem] = []
    @Relationship(deleteRule: .cascade, inverse: \CommitmentEdit.plan)
    var edits: [CommitmentEdit] = []

    init(weekStart: Date) {
        self.weekStart = weekStart
    }

    var isCommitted: Bool { committedAt != nil }
    /// Handed in and counting down to being sealed.
    var isSealing: Bool { committedAt == nil && submittedAt != nil }
    var sealDate: Date? { isSealing ? submittedAt?.addingTimeInterval(PlanService.sealDelay) : nil }
    var weekEnd: Date { weekStart.addingDays(7) }
    var lastDay: Date { weekStart.addingDays(6) }

    var activeTasks: [TaskItem] { tasks.filter { !$0.isRemoved } }
    /// Recovery tasks are extra work on top of the plan, never part of the promise.
    var committableTasks: [TaskItem] { activeTasks.filter { !$0.isRecovery } }
    var committedTasks: [TaskItem] { tasks.filter(\.isCommitted) }
    /// What sealing turns into commitments: only tasks that are still open. Whatever is already done
    /// or missed stays outside the promise, so a finished week cannot be pledged in hindsight.
    func pledgeableTasks(_ now: Date = .now) -> [TaskItem] {
        committableTasks.filter { $0.status == .pending && !$0.dayHasPassed(now) }
    }

    var originalSnapshot: [TaskSnapshot] {
        guard let snapshotData else { return [] }
        return (try? JSONDecoder().decode([TaskSnapshot].self, from: snapshotData)) ?? []
    }
}

/// Immutable copy of a task at the moment of commitment.
struct TaskSnapshot: Codable {
    let uid: UUID
    let title: String
    let category: TaskCategory
    let priority: TaskPriority
    let weight: Int
    let date: Date
    let deadline: Date?
    let plannedMinutes: Int
    let why: String

    init(_ task: TaskItem) {
        uid = task.uid
        title = task.title
        category = task.category
        priority = task.priority
        weight = task.weight
        date = task.scheduledDate
        deadline = task.deadline
        plannedMinutes = task.plannedMinutes
        why = task.why
    }
}

/// One change made to a plan after it was committed.
@Model
final class CommitmentEdit {
    var date: Date = Date()
    var kindRaw: String = EditKind.moved.rawValue
    var taskUID: UUID = UUID()
    var taskTitle: String = ""
    /// Human-readable "old → new".
    var detail: String = ""
    var plan: WeeklyPlan?

    init(kind: EditKind, task: TaskItem, detail: String) {
        self.kindRaw = kind.rawValue
        self.taskUID = task.uid
        self.taskTitle = task.title
        self.detail = detail
    }

    var kind: EditKind { EditKind(rawValue: kindRaw) ?? .moved }
}
