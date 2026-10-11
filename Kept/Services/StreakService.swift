import Foundation

/// The day streak beyond its plain count: when it broke, whether it can still be bought back
/// and which day will break it next.
enum StreakService {
    /// A broken streak can be bought back for this many days after the day that broke it:
    /// 48 hours from the midnight at which it ended.
    static let repairWindowDays = 2
    /// Shorter streaks are not offered for repair.
    static let minimumRepairableStreak = 2
    private static let lookAheadDays = 7

    /// A streak that ended, together with the days that have failed since.
    struct Broken {
        /// How long the streak was before it broke. 0 when there was none.
        let length: Int
        /// Past days under 80 % since the last good day, oldest first.
        let failedDays: [Date]

        var brokenOn: Date { failedDays[0] }
        var cost: Int { failedDays.count * PointsService.streakRepairCost }
        /// The last day on which it can still be bought back.
        var repairDeadline: Date { brokenOn.addingDays(StreakService.repairWindowDays) }
        /// The moment the offer runs out.
        var repairEnds: Date { repairDeadline.endOfDay }

        func canRepair(now: Date = .now) -> Bool {
            length >= StreakService.minimumRepairableStreak && now.startOfDay <= repairDeadline
        }
    }

    /// The most recent break, looking back from yesterday. Nil while no past day has failed since the last good one.
    /// Today is left out: it can still be saved, and a good today simply joins a repaired streak.
    static func broken(_ tasks: [TaskItem], now: Date = .now) -> Broken? {
        let byDay = Dictionary(grouping: tasks) { $0.scheduledDate.startOfDay }
        let repaired = ScoreEngine.repairedDays(tasks)
        guard let earliest = byDay.keys.min() else { return nil }

        var failed: [Date] = []
        var length = 0
        var day = now.startOfDay.addingDays(-1)
        while day >= earliest {
            if !repaired.contains(day), let score = ScoreEngine.productivity(byDay[day] ?? [], now: now) {
                if score >= ScoreEngine.Config.streakThreshold {
                    length += 1
                } else if length == 0 {
                    failed.append(day)
                } else {
                    break
                }
            }
            day = day.addingDays(-1)
        }
        guard !failed.isEmpty else { return nil }
        return Broken(length: length, failedDays: failed.reversed())
    }

    /// The first day from today on that breaks the streak if nothing more gets done.
    static func nextBreak(_ tasks: [TaskItem], now: Date = .now) -> Date? {
        let byDay = Dictionary(grouping: tasks) { $0.scheduledDate.startOfDay }
        return (0..<lookAheadDays).map { now.startOfDay.addingDays($0) }.first { day in
            guard let score = ScoreEngine.productivity(byDay[day] ?? [], now: now) else { return false }
            return score < ScoreEngine.Config.streakThreshold
        }
    }

    /// Buys the streak back: the failed days stop breaking it. Their tasks and scores stay as they are.
    static func repair(_ broken: Broken, tasks: [TaskItem], now: Date = .now) {
        let days = Set(broken.failedDays)
        for task in tasks where days.contains(task.scheduledDate.startOfDay) {
            task.streakRepairDay = task.scheduledDate.startOfDay
            task.streakRepairedAt = now
        }
    }
}
