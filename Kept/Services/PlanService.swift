import Foundation
import SwiftData

/// Editable copy of a task used by the editor.
struct TaskDraft {
    var title = ""
    var category: TaskCategory = .newSkill
    var priority: TaskPriority = .medium
    var date: Date = .now
    var hasDeadline = false
    var deadlineTime: Date = .now
    var plannedMinutes = 60
    var weight = 2
    var notes = ""
    var why = ""
    var requiresProof = false
    var usesFocus = false
    var isRecovery = false
    var fromSuggestion = false
    var stake = ""

    init(date: Date) {
        self.date = date.startOfDay
        self.deadlineTime = date.settingTime(from: Calendar.app.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? date)
    }

    init(task: TaskItem) {
        title = task.title
        category = task.category
        priority = task.priority
        date = task.scheduledDate
        hasDeadline = task.deadline != nil
        deadlineTime = task.deadline ?? task.scheduledDate.addingTimeInterval(18 * 3600)
        plannedMinutes = task.plannedMinutes
        weight = task.weight
        notes = task.notes
        why = task.why
        requiresProof = task.requiresProof
        stake = task.stake
        usesFocus = task.usesFocus
        isRecovery = task.isRecovery
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Everything that creates or changes plans and tasks goes through here, so that
/// changes to a committed plan are always recorded.
enum PlanService {
    static func plan(forWeekOf date: Date, in context: ModelContext) -> WeeklyPlan {
        let weekStart = date.weekStart
        let descriptor = FetchDescriptor<WeeklyPlan>(predicate: #Predicate { $0.weekStart == weekStart })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let plan = WeeklyPlan(weekStart: weekStart)
        context.insert(plan)
        return plan
    }

    /// How long a handed-in plan can still be changed before it is sealed. Nobody can shorten it.
    static let sealDelay: TimeInterval = 60 * 60

    /// Hands the plan in. It becomes a commitment by itself once `sealDelay` has passed.
    static func submit(_ plan: WeeklyPlan, at now: Date = .now) {
        plan.submittedAt = now
    }

    /// Takes a handed-in plan back before it is sealed.
    static func withdraw(_ plan: WeeklyPlan) {
        plan.submittedAt = nil
    }

    /// A week planned ahead (up to the end of its Monday) must contain the minimum number of activities.
    static func missesMinimum(_ plan: WeeklyPlan, minimum: Int, now: Date = .now) -> Bool {
        plan.committableTasks.count < minimum && now < plan.weekStart.addingDays(1)
    }

    /// Whether a handed-in plan really gets sealed when its hour runs out.
    static func willSeal(_ plan: WeeklyPlan, minimum: Int) -> Bool {
        guard let sealDate = plan.sealDate else { return false }
        return !plan.pledgeableTasks(sealDate).isEmpty && !missesMinimum(plan, minimum: minimum, now: sealDate)
    }

    /// Seals every plan whose hour is over, as of the moment it ran out. A plan that was emptied
    /// or cut below the minimum in the meantime goes back to being a draft instead.
    static func sealDue(_ plans: [WeeklyPlan], minimum: Int, now: Date = .now) {
        for plan in plans {
            guard let sealDate = plan.sealDate, sealDate <= now else { continue }
            if !willSeal(plan, minimum: minimum) {
                withdraw(plan)
            } else {
                commit(plan, at: sealDate)
            }
        }
    }

    /// Freezes the current plan as the original commitment.
    static func commit(_ plan: WeeklyPlan, at now: Date = .now) {
        let tasks = plan.pledgeableTasks(now)
        for task in tasks {
            task.isCommitted = true
            task.originalDate = task.scheduledDate
            task.originalWeight = task.weight
            task.originalPriorityRaw = task.priorityRaw
        }
        plan.snapshotData = try? JSONEncoder().encode(tasks.map(TaskSnapshot.init))
        plan.committedAt = now
    }

    @discardableResult
    static func save(_ draft: TaskDraft, to existing: TaskItem?, in context: ModelContext) -> TaskItem {
        let day = draft.date.startOfDay
        let deadline = draft.hasDeadline ? day.settingTime(from: draft.deadlineTime) : nil
        let plan = plan(forWeekOf: day, in: context)

        let task: TaskItem
        if let existing {
            task = existing
            if task.isCommitted {
                recordChanges(to: task, day: day, deadline: deadline, draft: draft)
            }
            task.title = draft.trimmedTitle
            task.category = draft.category
            task.priority = draft.priority
            task.weight = draft.weight
            task.scheduledDate = day
        } else {
            task = TaskItem(title: draft.trimmedTitle, category: draft.category, priority: draft.priority,
                            weight: draft.weight, scheduledDate: day)
            task.isRecovery = draft.isRecovery
            task.fromSuggestion = draft.fromSuggestion
            context.insert(task)
        }
        task.requiresProof = draft.requiresProof
        task.stake = draft.stake.trimmingCharacters(in: .whitespacesAndNewlines)
        task.usesFocus = draft.usesFocus
        task.deadline = deadline
        task.plannedMinutes = draft.plannedMinutes
        task.notes = draft.notes
        task.why = draft.why

        if task.plan !== plan {
            task.plan = plan
            if plan.isCommitted, !task.isCommitted, !task.isRecovery {
                log(.addedLater, task: task, detail: day.shortDayText, in: plan)
            }
        }
        return task
    }

    /// Plans the same tasks a week later, on the same weekdays. Days that are already over are left out,
    /// and so is anything the target day already holds under the same title.
    /// Returns how many tasks were created.
    @discardableResult
    static func copyWeek(_ source: WeeklyPlan, in context: ModelContext, now: Date = .now) -> Int {
        var copied = 0
        let existing = plan(forWeekOf: source.weekStart.addingDays(7), in: context).activeTasks
        for task in source.committableTasks {
            var draft = TaskDraft(task: task)
            draft.date = task.scheduledDate.addingDays(7)
            guard draft.date.endOfDay > now,
                  !existing.contains(where: { $0.title.activityKey == task.title.activityKey && $0.scheduledDate.isSameDay(as: draft.date) })
            else { continue }
            draft.deadlineTime = draft.date.settingTime(from: draft.deadlineTime)
            save(draft, to: nil, in: context)
            copied += 1
        }
        return copied
    }

    /// A committed task is only hidden and keeps counting as a broken promise; a draft task is really deleted.
    static func remove(_ task: TaskItem, in context: ModelContext, at now: Date = .now) {
        guard task.isCommitted, let plan = task.plan else {
            context.delete(task)
            return
        }
        task.isRemoved = true
        task.removedAt = now
        log(.removed, task: task, detail: task.scheduledDate.shortDayText, in: plan)
    }

    // MARK: Postponing

    static func postponementsUsed(_ postponements: [Postponement], now: Date = .now) -> Int {
        postponements.filter { Calendar.app.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    /// Moves a task to another day as one of the month's penalty-free postponements:
    /// no failure, no commitment edit, the promise simply moves with it.
    static func postpone(_ task: TaskItem, to day: Date, in context: ModelContext, now: Date = .now) {
        let from = task.scheduledDate
        let target = day.startOfDay
        task.finishFocusSessions(at: now)
        if let deadline = task.deadline {
            task.deadline = target.settingTime(from: deadline)
        }
        task.scheduledDate = target
        let plan = plan(forWeekOf: target, in: context)
        if task.plan !== plan {
            task.plan = plan
        }
        context.insert(Postponement(task: task, from: from, to: target, now: now))
    }

    private static func recordChanges(to task: TaskItem, day: Date, deadline: Date?, draft: TaskDraft) {
        guard let plan = task.plan else { return }
        var changed = false

        if !day.isSameDay(as: task.scheduledDate) {
            log(.moved, task: task, detail: "\(task.scheduledDate.shortDayText) → \(day.shortDayText)", in: plan)
            task.moveCount += 1
            changed = true
        }
        if draft.priority != task.priority {
            let kind: EditKind = draft.priority.rank < task.priority.rank ? .priorityLowered : .priorityRaised
            log(kind, task: task, detail: "\(task.priority.title) → \(draft.priority.title)", in: plan)
            changed = true
        }
        // Compare clock times only: moving a task to another day shifts its deadline without changing it.
        let oldTime = task.deadline?.minutesIntoDay
        let newTime = deadline?.minutesIntoDay
        if oldTime != newTime {
            let detail = "\(task.deadline?.timeText ?? "žádný") → \(deadline?.timeText ?? "žádný")"
            log(.deadlineChanged, task: task, detail: detail, in: plan)
            changed = true
        }
        if draft.weight != task.weight {
            let kind: EditKind = draft.weight < task.weight ? .weightLowered : .weightRaised
            log(kind, task: task, detail: "\(task.weight) → \(draft.weight)", in: plan)
            changed = true
        }
        if changed {
            task.editedAfterCommitment = true
        }
    }

    private static func log(_ kind: EditKind, task: TaskItem, detail: String, in plan: WeeklyPlan) {
        let edit = CommitmentEdit(kind: kind, task: task, detail: detail)
        edit.plan = plan
        plan.modelContext?.insert(edit)
    }
}
