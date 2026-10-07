import Foundation
import SwiftData

/// One use of the monthly "postpone without penalty" allowance.
@Model
final class Postponement {
    var date: Date = Date()
    var taskTitle: String = ""
    var fromDay: Date = Date()
    var toDay: Date = Date()

    init(task: TaskItem, from: Date, to: Date, now: Date = .now) {
        self.date = now
        self.taskTitle = task.title
        self.fromDay = from
        self.toDay = to
    }
}

/// End-of-week self-reflection: the journal entry plus the numbers of that week as they stood when it was written.
@Model
final class WeekReflection {
    var weekStart: Date = Date()
    var createdAt: Date = Date()
    /// 1 (not at all) … 5 (completely).
    var satisfaction: Int = 3
    var text: String = ""
    var doneCount: Int = 0
    var totalCount: Int = 0
    var promisesKept: Double?
    var productivity: Double?

    init(weekStart: Date) {
        self.weekStart = weekStart
    }

    static let satisfactionLabels = ["Vůbec", "Spíš ne", "Tak napůl", "Spíš ano", "Naprosto"]

    var satisfactionLabel: String {
        WeekReflection.satisfactionLabels[min(max(satisfaction, 1), 5) - 1]
    }
}
