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
    /// UserDefaults key: day (as a timestamp) of the break whose buy-back offer the user turned down.
    static let offerDismissedKey = "streakOfferDismissed"

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
            guard !RestDays.contains(day) else { return false }
            guard let score = ScoreEngine.productivity(byDay[day] ?? [], now: now) else { return false }
            return score < ScoreEngine.Config.streakThreshold
        }
    }

    // MARK: Milestones

    struct Milestone: Identifiable {
        let days: Int
        /// One-off points for reaching it.
        let bonus: Int
        /// End of the day on which the streak first got this long. Nil while it has not.
        let reachedOn: Date?
        var id: Int { days }
    }

    private static let milestoneSteps: [(days: Int, bonus: Int)] = [(3, 50), (7, 100), (14, 150), (30, 300), (60, 500), (100, 1000)]

    /// Every milestone with the day it was first reached, replayed from the whole history.
    static func milestones(_ tasks: [TaskItem], now: Date = .now) -> [Milestone] {
        let byDay = Dictionary(grouping: tasks) { $0.scheduledDate.startOfDay }
        let repaired = ScoreEngine.repairedDays(tasks)
        let today = now.startOfDay
        var reached: [Int: Date] = [:]
        var run = 0
        for day in byDay.keys.sorted() where day <= today && !repaired.contains(day) {
            guard let score = ScoreEngine.productivity(byDay[day] ?? [], now: now) else { continue }
            if score >= ScoreEngine.Config.streakThreshold {
                run += 1
                for step in milestoneSteps where step.days == run && reached[run] == nil {
                    reached[run] = min(day.endOfDay, now)
                }
            } else if day < today {
                run = 0
            }
        }
        return milestoneSteps.map { Milestone(days: $0.days, bonus: $0.bonus, reachedOn: reached[$0.days]) }
    }

    // MARK: Insurance

    /// Spends waiting streak insurances on the days that broke the streak, oldest first.
    /// An insurance only covers a day that ended after it was bought.
    static func applyInsurance(tasks: [TaskItem], purchases: [PointsPurchase], now: Date = .now) {
        guard let broken = broken(tasks, now: now), broken.length > 0 else { return }
        var waiting = purchases.filter { $0.kind == .streakInsurance && $0.usedOn == nil }.sorted { $0.date < $1.date }
        for day in broken.failedDays {
            guard let index = waiting.firstIndex(where: { $0.date < day.endOfDay }) else { return }
            waiting.remove(at: index).usedOn = day
            // No `streakRepairedAt`: the day is covered by the insurance, not bought back for points.
            for task in tasks where task.scheduledDate.startOfDay == day {
                task.streakRepairDay = day
            }
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
