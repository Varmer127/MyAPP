import Foundation
import SwiftData

/// The answers given in the No Excuses flow. Task details are copied so the
/// record stays meaningful for pattern detection even if the task changes.
@Model
final class FailureRecord {
    var date: Date = Date()
    var kindRaw: String = FailureKind.skipped.rawValue
    var reasonRaw: String = FailureReason.other.rawValue
    var critique: String = ""
    var prevention: String = ""
    var taskTitle: String = ""
    var categoryRaw: String = TaskCategory.other.rawValue
    var priorityRaw: String = TaskPriority.medium.rawValue
    /// Day the task was scheduled on.
    var taskDate: Date = Date()
    var task: TaskItem?

    init(task: TaskItem, kind: FailureKind, reason: FailureReason, critique: String, prevention: String) {
        self.kindRaw = kind.rawValue
        self.reasonRaw = reason.rawValue
        self.critique = critique
        self.prevention = prevention
        self.taskTitle = task.title
        self.categoryRaw = task.categoryRaw
        self.priorityRaw = task.scoringPriority.rawValue
        self.taskDate = task.scheduledDate
        self.task = task
    }

    var kind: FailureKind { FailureKind(rawValue: kindRaw) ?? .skipped }
    var reason: FailureReason { FailureReason(rawValue: reasonRaw) ?? .other }
    var category: TaskCategory { TaskCategory(rawValue: categoryRaw) ?? .other }

    /// Key used to recognise "the same task" across days.
    var titleKey: String { FailureRecord.key(for: taskTitle) }

    static func key(for title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
