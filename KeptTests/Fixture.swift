import Foundation
import SwiftData
@testable import Kept

/// Shared test data: a fixed "now" so nothing depends on the day the tests run.
enum Fixture {
    /// Wednesday 21 October 2026, 12:00.
    static let now: Date = Calendar.app.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 12))!

    /// A task `day` days from `now`; `done` completes it at ten in the morning of its day.
    static func task(_ title: String = "Úkol", day: Int = 0, done: Bool = false, weight: Int = 2,
                     category: TaskCategory = .work, priority: TaskPriority = .medium) -> TaskItem {
        let date = now.addingDays(day)
        let task = TaskItem(title: title, category: category, priority: priority, weight: weight, scheduledDate: date)
        if done { task.markDone(at: date.startOfDay.addingTimeInterval(10 * 3600)) }
        return task
    }

    /// Plain tasks on consecutive days ending `lastDay` days from now, all done or all open.
    static func days(_ range: ClosedRange<Int>, done: Bool = true) -> [TaskItem] {
        range.map { task(day: $0, done: done) }
    }

    /// A context's container must outlive the context, or the first use crashes: they are kept for the whole test run.
    @MainActor private static var containers: [ModelContainer] = []

    @MainActor
    static func context() throws -> ModelContext {
        let schema = Schema(versionedSchema: KeptSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        containers.append(container)
        return container.mainContext
    }
}
