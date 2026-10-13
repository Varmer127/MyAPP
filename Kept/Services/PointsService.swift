import Foundation

/// Points earned by keeping commitments, spent on a pass that cancels one commitment without penalty
/// or on buying back a broken streak.
/// The balance is derived from history every time, so undoing a completion also takes its points back.
enum PointsService {
    /// A fully kept weekly commitment; partial or late completion earns its share.
    static let perCommitment = 100
    /// A completed task that was added from one of the app's own suggestions.
    static let perSuggestion = 50
    static let passCost = 1000
    /// At most this many passes can be saved up; points earned beyond that are lost.
    static let maxStoredPasses = 2
    /// Buying back a broken streak, for every day that broke it.
    static let streakRepairCost = 500

    /// Everyone starts with this much, so the first pass is within reach.
    static let startingBalance = 750

    static var cap: Int { passCost * maxStoredPasses }

    /// Points a task has earned so far.
    static func earned(by task: TaskItem) -> Int {
        guard task.isDone else { return 0 }
        if task.isCommitted {
            return Int((Double(perCommitment) * task.completionFactor).rounded())
        }
        return task.fromSuggestion ? perSuggestion : 0
    }

    /// Current balance: earnings, milestone bonuses, shop purchases, spent passes and streak repairs replayed in time order, with the cap applied along the way.
    static func balance(_ tasks: [TaskItem], purchases: [PointsPurchase], now: Date = .now) -> Int {
        var events: [(date: Date, change: Int)] = purchases.map { ($0.date, -$0.cost) }
        for milestone in StreakService.milestones(tasks, now: now) {
            if let reachedOn = milestone.reachedOn {
                events.append((reachedOn, milestone.bonus))
            }
        }
        for task in tasks {
            let points = earned(by: task)
            if points > 0 {
                events.append((task.completedAt ?? task.scheduledDate, points))
            }
            if let redeemedAt = task.redeemedAt {
                events.append((redeemedAt, -passCost))
            }
        }
        // One charge per repaired day, however many tasks that day had.
        for day in Dictionary(grouping: tasks.filter { $0.streakRepairDay != nil }, by: \.streakRepairDay).values {
            if let repairedAt = day.compactMap(\.streakRepairedAt).min() {
                events.append((repairedAt, -streakRepairCost))
            }
        }
        return events.sorted { $0.date < $1.date }.reduce(startingBalance) { balance, event in
            event.change > 0 ? min(cap, balance + event.change) : max(0, balance + event.change)
        }
    }

    static func unused(_ item: ShopItem, in purchases: [PointsPurchase]) -> Int {
        purchases.filter { $0.kind == item && $0.usedOn == nil }.count
    }

    /// Extra postponements bought for the current month.
    static func extraPostponements(_ purchases: [PointsPurchase], now: Date = .now) -> Int {
        purchases.filter { $0.kind == .extraPostpone && Calendar.app.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    static func canBuy(_ item: ShopItem, balance: Int, purchases: [PointsPurchase]) -> Bool {
        balance >= item.cost && item.maxStored.map { unused(item, in: purchases) < $0 } ?? true
    }

    /// Only a real weekly commitment that is still open can be cancelled with a pass.
    static func canRedeem(_ task: TaskItem, balance: Int, now: Date = .now) -> Bool {
        balance >= passCost && task.isCommitted && task.status == .pending && !task.isRemoved && !task.isMissed(now)
    }

    /// Cancels the commitment without penalty. It stays in the history as cancelled for points.
    static func redeem(_ task: TaskItem, now: Date = .now) {
        task.finishFocusSessions(at: now)
        task.redeemedAt = now
        task.status = .excused
    }
}
