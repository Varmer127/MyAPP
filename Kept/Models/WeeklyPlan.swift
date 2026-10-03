import Foundation
import SwiftData

@Model
final class WeeklyPlan {
    /// Monday 00:00 of the week.
    var weekStart: Date = Date()
    /// Set when the user presses I COMMIT. Nil while the plan is a draft.
    var committedAt: Date?
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
    var weekEnd: Date { weekStart.addingDays(7) }
    var lastDay: Date { weekStart.addingDays(6) }

    var activeTasks: [TaskItem] { tasks.filter { !$0.isRemoved } }
    var committedTasks: [TaskItem] { tasks.filter(\.isCommitted) }

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
