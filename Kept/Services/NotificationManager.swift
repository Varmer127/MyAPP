import Foundation
import SwiftData
import UserNotifications
import os

enum AppRoute: String {
    case today, planning, realityCheck
}

/// Receives notification taps and tells the UI where to go.
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    static let routeKey = "route"

    @Published var route: AppRoute?

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let raw = response.notification.request.content.userInfo[Self.routeKey] as? String
        let route = raw.flatMap(AppRoute.init(rawValue:)) ?? .today
        await MainActor.run { self.route = route }
    }
}

/// iOS gives an app no background time to decide what to send, so nothing here is "live":
/// every call wipes the pending notifications and schedules the whole upcoming series again
/// from the current data. Completing a task therefore cancels the rest of its escalation.
@MainActor
enum NotificationManager {
    /// iOS keeps at most 64 pending local notifications per app.
    private static let maxPending = 60
    private static let prepLead: TimeInterval = 30 * 60
    private static let directDelay: TimeInterval = 15 * 60
    private static let overdueRepeats = 2
    private static let nudgeHours = [12, 16, 19]
    private static let daysAhead = 2
    private static let briefDaysAhead = 3
    private static let failureWindowDays = 30
    private static let repeatedFailureCount = 3
    private static let weakPromisesKept = 0.6
    private static let focusEndID = "focus.end"

    private struct Planned {
        let id: String
        let date: Date
        let title: String
        let body: String
        let route: AppRoute
    }

    private static let logger = Logger(subsystem: "cz.philipstryka.kept", category: "notifications")

    private static var center: UNUserNotificationCenter { .current() }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    static func reschedule(context: ModelContext, now: Date = .now) async {
        let planned = plan(context: context, now: now)
        // Everything is replaced except the running focus timer's end notification.
        let stale = await center.pendingNotificationRequests().map(\.identifier).filter { $0 != focusEndID }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.userInfo = [NotificationRouter.routeKey: item.route.rawValue]
            let parts = Calendar.app.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
        let summary = planned.map { "\($0.date.stampText) [\($0.id.prefix(12))] \($0.body)" }.joined(separator: "\n")
        logger.info("Scheduled \(planned.count) notifications:\n\(summary, privacy: .public)")
    }

    static func scheduleFocusEnd(title: String, in seconds: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = title.uppercased()
        content.body = "Naplánovaný čas vypršel. Dokonči úkol, nebo pokračuj."
        content.sound = .default
        content.userInfo = [NotificationRouter.routeKey: AppRoute.today.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: focusEndID, content: content, trigger: trigger))
    }

    static func cancelFocusEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [focusEndID])
    }

    /// Fires one sample of the chosen tone a few seconds from now.
    static func sendPreview(tone: NotificationTone) async {
        let content = UNMutableNotificationContent()
        content.title = "CLAUDE WORK"
        content.body = NotificationTemplates.taskMessage(
            level: tone.maxLevel, title: "Claude Work", time: Date.now.timeText, why: "",
            failures: 0, seed: Int.random(in: 0..<1000))
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "preview", content: content, trigger: trigger))
    }

    // MARK: Planning

    private static func plan(context: ModelContext, now: Date) -> [Planned] {
        let settings = UserSettings.current(in: context)
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<WeeklyPlan>())) ?? []
        let failures = (try? context.fetch(FetchDescriptor<FailureRecord>())) ?? []

        var planned: [Planned] = []
        if settings.sundayRemindersEnabled {
            planned += sundayReminders(settings: settings, plans: plans, now: now)
        }
        if settings.morningBriefEnabled {
            planned += morningBriefs(settings: settings, tasks: tasks, now: now)
        }
        if settings.realityCheckEnabled {
            planned += realityChecks(settings: settings, tasks: tasks, now: now)
        }
        if settings.taskRemindersEnabled {
            planned += taskReminders(settings: settings, tasks: tasks, failures: failures, now: now)
            planned += dayNudges(settings: settings, tasks: tasks, now: now)
        }
        return Array(planned.filter { $0.date > now }.sorted { $0.date < $1.date }.prefix(maxPending))
    }

    private static func time(_ minutes: Int, on day: Date) -> Date {
        day.startOfDay.addingTimeInterval(TimeInterval(minutes * 60))
    }

    private static func openTasks(_ tasks: [TaskItem], on day: Date) -> [TaskItem] {
        tasks.filter { $0.status == .pending && !$0.isRemoved && $0.scheduledDate.isSameDay(as: day) }
    }

    /// Hourly on the coming Sunday until next week's plan is committed.
    private static func sundayReminders(settings: UserSettings, plans: [WeeklyPlan], now: Date) -> [Planned] {
        let sunday = now.weekStart.addingDays(6)
        let nextWeek = now.weekStart.addingDays(7)
        guard plans.first(where: { $0.weekStart == nextWeek })?.isCommitted != true,
              settings.sundayStartHour <= settings.sundayEndHour else { return [] }

        return (settings.sundayStartHour...settings.sundayEndHour).enumerated().map { index, hour in
            Planned(id: "sunday.\(hour)", date: time(hour * 60, on: sunday), title: "PLÁN TÝDNE",
                    body: NotificationTemplates.sunday(tone: settings.tone, index: index), route: .planning)
        }
    }

    private static func morningBriefs(settings: UserSettings, tasks: [TaskItem], now: Date) -> [Planned] {
        (0..<briefDaysAhead).compactMap { offset in
            let day = now.startOfDay.addingDays(offset)
            let open = openTasks(tasks, on: day)
            guard !open.isEmpty else { return nil }

            let critical = open.filter { $0.priority == .critical }
            let deadlines = open.filter { $0.deadline != nil }.count
            var lines = ["Dnešní závazky: \(open.count). Kritické: \(critical.count). S deadlinem: \(deadlines)."]
            if let focus = critical.first {
                lines.append("Hlavní fokus: \(focus.title).")
            }
            // Only today's brief can honestly refer to how yesterday went.
            if offset == 0 {
                let yesterday = tasks.filter { $0.scheduledDate.isSameDay(as: day.addingDays(-1)) }
                lines.append(NotificationTemplates.morningSentence(
                    yesterday: ScoreEngine.productivity(yesterday, now: now), seed: day.daySeed))
            }
            return Planned(id: "brief.\(offset)", date: time(settings.morningBriefMinutes, on: day),
                           title: "RANNÍ PŘEHLED", body: lines.joined(separator: " "), route: .today)
        }
    }

    private static func realityChecks(settings: UserSettings, tasks: [TaskItem], now: Date) -> [Planned] {
        (0..<daysAhead).compactMap { offset in
            let day = now.startOfDay.addingDays(offset)
            let all = tasks.filter { !$0.isRemoved && $0.scheduledDate.isSameDay(as: day) }
            guard !all.isEmpty else { return nil }

            let done = all.filter(\.isDone).count
            let open = all.filter { $0.status == .pending }.count
            let body: String
            if offset == 0, done == all.count {
                body = "Dnes \(done) / \(all.count). Slovo dodrženo."
            } else if offset == 0 {
                body = "Dnešní závazky: \(all.count). Hotovo: \(done). Otevřeno: \(open). Otevři večerní bilanci."
            } else {
                body = NotificationTemplates.pick(NotificationTemplates.realityCheck[settings.tone] ?? [], seed: day.daySeed)
                    .replacingOccurrences(of: "{n}", with: "\(all.count)")
            }
            return Planned(id: "reality.\(offset)", date: time(settings.realityCheckMinutes, on: day),
                           title: "VEČERNÍ BILANCE", body: body, route: .realityCheck)
        }
    }

    /// Aggregated "N still open" reminders at fixed hours, sharpening through the day.
    private static func dayNudges(settings: UserSettings, tasks: [TaskItem], now: Date) -> [Planned] {
        let pool = NotificationTemplates.dayNudge[settings.tone] ?? []
        return (0..<daysAhead).flatMap { offset -> [Planned] in
            let day = now.startOfDay.addingDays(offset)
            let open = openTasks(tasks, on: day).count
            guard open > 0 else { return [] }
            return nudgeHours.enumerated().map { index, hour in
                let body = pool.isEmpty ? "" : pool[min(index, pool.count - 1)]
                return Planned(id: "nudge.\(offset).\(hour)", date: time(hour * 60, on: day), title: "KEPT",
                               body: body.replacingOccurrences(of: "{n}", with: "\(open)"), route: .today)
            }
        }
    }

    /// Per-task escalation series for today and tomorrow.
    private static func taskReminders(settings: UserSettings, tasks: [TaskItem],
                                      failures: [FailureRecord], now: Date) -> [Planned] {
        let since = now.startOfDay.addingDays(-failureWindowDays)
        let recentFailures = Dictionary(grouping: failures.filter { $0.date >= since }, by: \.titleKey)
        let weekTasks = tasks.filter { $0.scheduledDate.weekStart == now.weekStart }
        let promisesAreWeak = (ScoreEngine.promisesKept(weekTasks, now: now) ?? 1) < weakPromisesKept

        return (0..<daysAhead).flatMap { offset -> [Planned] in
            openTasks(tasks, on: now.startOfDay.addingDays(offset)).flatMap { task -> [Planned] in
                let failureCount = recentFailures[FailureRecord.key(for: task.title)]?.count ?? 0
                var boost = 0
                if task.scoringPriority == .critical { boost += 1 }
                if failureCount >= repeatedFailureCount { boost += 1 }
                if promisesAreWeak { boost += 1 }

                return steps(for: task, settings: settings).map { step in
                    // Preparation and start stay factual; later steps sharpen with the boosts, capped by the tone.
                    let level = step.level <= 1 ? step.level : min(settings.tone.maxLevel, step.level + boost)
                    let body = NotificationTemplates.taskMessage(
                        level: level, title: task.title, time: step.date.timeText, why: task.why,
                        failures: failureCount, seed: task.uid.hashValue &+ step.index)
                    return Planned(id: "task.\(task.uid.uuidString).\(step.index)", date: step.date,
                                   title: task.title.uppercased(), body: body, route: .today)
                }
            }
        }
    }

    /// Base timeline of one task. A task without a deadline has no start time, so it only
    /// gets a "last chance to start" before the evening Reality Check.
    private static func steps(for task: TaskItem, settings: UserSettings) -> [(index: Int, date: Date, level: Int)] {
        let duration = TimeInterval(task.plannedMinutes * 60)
        guard let deadline = task.deadline else {
            let lastChance = time(settings.realityCheckMinutes, on: task.scheduledDate).addingTimeInterval(-duration)
            return [(0, lastChance, 2)]
        }

        let start = deadline.addingTimeInterval(-duration)
        var steps: [(Int, Date, Int)] = [
            (0, start.addingTimeInterval(-prepLead), 0),
            (1, start, 1),
        ]
        if start.addingTimeInterval(directDelay) < deadline {
            steps.append((2, start.addingTimeInterval(directDelay), 2))
        }
        steps.append((3, deadline, 3))
        let gap = TimeInterval(settings.overdueRepeatMinutes * 60)
        for repeatIndex in 1...overdueRepeats {
            steps.append((3 + repeatIndex, deadline.addingTimeInterval(gap * Double(repeatIndex)), 4))
        }
        return steps
    }
}
