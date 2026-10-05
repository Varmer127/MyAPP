import Foundation

/// All score formulas in one place. Pure functions over tasks and plans — nothing is stored,
/// so scores can never drift from the underlying history.
enum ScoreEngine {
    enum Config {
        static let lateWithinHourFactor = 0.9
        static let lateWithinDayFactor = 0.8
        static let lateBeyondDayFactor = 0.7
        /// Productivity is multiplied by (1 - this × share of critical tasks lost).
        static let criticalLossPenalty = 0.10
        /// Share of a recovery task's weight added on top of earned points.
        static let recoveryBonus = 0.5
        static let streakThreshold = 0.8
        static let accountabilityWindowDays = 30

        static let promisesKeptShare = 0.45
        static let productivityShare = 0.25
        static let integrityShare = 0.15
        static let onTimeShare = 0.15

        static let unexplainedPenalty = 1.0
        static let unexplainedPenaltyCap = 10.0
        static let criticalLostPenalty = 2.0
        static let criticalLostPenaltyCap = 10.0
        static let repeatedFailureThreshold = 3
        static let repeatedFailurePenalty = 2.0
        static let repeatedFailurePenaltyCap = 6.0
        static let recoveryPointBonus = 1.0
        static let recoveryPointBonusCap = 5.0
        static let streakPointBonus = 0.5
        static let streakPointBonusCap = 5.0
    }

    static func lateFactor(delay: TimeInterval) -> Double {
        let hour: TimeInterval = 3600
        if delay <= hour { return Config.lateWithinHourFactor }
        if delay <= 24 * hour { return Config.lateWithinDayFactor }
        return Config.lateBeyondDayFactor
    }

    // MARK: Productivity

    /// Weighted productivity (0...1): earned points / possible points, reduced when critical tasks are lost.
    /// Open tasks count as not yet earned, so pass only the tasks that should be judged.
    static func productivity(_ tasks: [TaskItem], now: Date = .now) -> Double? {
        let regular = tasks.filter { !$0.isRecovery }
        let possible = regular.reduce(0.0) { $0 + Double($1.scoringWeight) }
        guard possible > 0 else { return nil }

        var earned = regular.reduce(0.0) { $0 + Double($1.scoringWeight) * $1.completionFactor }
        earned += tasks.filter { $0.isRecovery && $0.isDone }
            .reduce(0.0) { $0 + Double($1.weight) * Config.recoveryBonus }

        var score = min(earned / possible, 1)
        let critical = regular.filter { $0.scoringPriority == .critical }
        if !critical.isEmpty {
            let lost = critical.filter { $0.isLost(now) }.count
            score *= 1 - Config.criticalLossPenalty * Double(lost) / Double(critical.count)
        }
        return score
    }

    /// Plain share of tasks done, ignoring weights. Only used to contrast "busy" with "productive".
    static func completionRate(_ tasks: [TaskItem]) -> Double? {
        let regular = tasks.filter { !$0.isRecovery }
        guard !regular.isEmpty else { return nil }
        return Double(regular.filter(\.isDone).count) / Double(regular.count)
    }

    static func isBusyNotProductive(_ tasks: [TaskItem], now: Date = .now) -> Bool {
        guard let rate = completionRate(tasks), let score = productivity(tasks, now: now) else { return false }
        return rate >= 0.6 && score < 0.5
    }

    // MARK: Promises Kept

    /// Kept commitments / all original commitments whose outcome is final.
    /// Removed and moved tasks stay in the denominator; tasks added after committing are not promises.
    static func promisesKept(_ tasks: [TaskItem], now: Date = .now) -> Double? {
        let promises = tasks.filter { $0.isCommitted && $0.isClosed(now) }
        guard !promises.isEmpty else { return nil }
        return Double(promises.filter(\.isDone).count) / Double(promises.count)
    }

    // MARK: Commitment Integrity

    /// 1 - (sum of per-task change penalties / original commitments). Each task costs at most 1.
    static func commitmentIntegrity(_ plan: WeeklyPlan) -> Double? {
        let originals = plan.committedTasks
        guard plan.isCommitted, !originals.isEmpty else { return nil }

        let editsByTask = Dictionary(grouping: plan.edits, by: \.taskUID)
        let penalty = originals.reduce(0.0) { total, task in
            let kinds = Set((editsByTask[task.uid] ?? []).map(\.kind))
            return total + min(kinds.reduce(0.0) { $0 + $1.integrityPenalty }, 1)
        }
        return max(0, 1 - penalty / Double(originals.count))
    }

    // MARK: Streak

    /// Consecutive days with productivity ≥ 80%. Days without tasks neither extend nor break it.
    static func dayStreak(_ tasks: [TaskItem], now: Date = .now) -> Int {
        let byDay = Dictionary(grouping: tasks) { $0.scheduledDate.startOfDay }
        let today = now.startOfDay
        guard let earliest = byDay.keys.min() else { return 0 }

        var streak = 0
        if let score = productivity(byDay[today] ?? [], now: now), score >= Config.streakThreshold {
            streak += 1
        }
        var day = today.addingDays(-1)
        while day >= earliest {
            if let score = productivity(byDay[day] ?? [], now: now) {
                guard score >= Config.streakThreshold else { break }
                streak += 1
            }
            day = day.addingDays(-1)
        }
        return streak
    }

    // MARK: Accountability

    struct Accountability {
        let score: Int
        let promisesKept: Double?
        let productivity: Double?
        let integrity: Double?
        let onTime: Double?
        let penalties: Double
        let bonus: Double
        let criticalLost: Int
        let unexplained: Int

        var subtitle: String {
            if unexplained > 0 { return "Máš selhání, která jsi ještě ani nevysvětlil." }
            if criticalLost > 0, score >= 60 { return "Většinou spolehlivý, ale kritickou práci necháváš padat." }
            switch score {
            case 85...: return "Držíš slovo."
            case 70..<85: return "Většinou spolehlivý. Růst je v tom, co ti uniká."
            case 50..<70: return "Porušuješ příliš mnoho vlastních slibů."
            default: return "Tvoje slovo teď moc neznamená. Změň to ještě dnes."
            }
        }
    }

    /// Rolling 30-day score, 0–100:
    /// 45% Promises Kept + 25% Productivity + 15% Commitment Integrity + 15% On-time rate,
    /// minus capped penalties, plus capped bonuses. Missing components are left out and the rest re-weighted.
    static func accountability(tasks: [TaskItem], plans: [WeeklyPlan], now: Date = .now) -> Accountability? {
        let from = now.startOfDay.addingDays(-Config.accountabilityWindowDays)
        let window = tasks.filter { $0.scheduledDate >= from && $0.isClosed(now) }
        guard !window.isEmpty else { return nil }

        let kept = promisesKept(window, now: now)
        let productive = productivity(window, now: now)
        let integrities = plans.filter { $0.weekEnd > from }.compactMap(commitmentIntegrity)
        let integrity = integrities.isEmpty ? nil : integrities.reduce(0, +) / Double(integrities.count)
        let done = window.filter(\.isDone)
        let onTime = done.isEmpty ? nil : Double(done.filter { $0.status == .completed }.count) / Double(done.count)

        let components: [(Double?, Double)] = [
            (kept, Config.promisesKeptShare),
            (productive, Config.productivityShare),
            (integrity, Config.integrityShare),
            (onTime, Config.onTimeShare),
        ]
        let present = components.compactMap { value, share in value.map { ($0, share) } }
        let totalShare = present.reduce(0.0) { $0 + $1.1 }
        let base = totalShare > 0 ? present.reduce(0.0) { $0 + $1.0 * $1.1 } / totalShare * 100 : 0

        let lost = window.filter { $0.isLost(now) }
        let unexplained = window.filter { $0.isMissed(now) }.count
        let criticalLost = lost.filter { $0.scoringPriority == .critical }.count
        let repeated = Dictionary(grouping: lost) { FailureRecord.key(for: $0.title) }
            .filter { $0.value.count >= Config.repeatedFailureThreshold }.count

        let penalties = min(Double(unexplained) * Config.unexplainedPenalty, Config.unexplainedPenaltyCap)
            + min(Double(criticalLost) * Config.criticalLostPenalty, Config.criticalLostPenaltyCap)
            + min(Double(repeated) * Config.repeatedFailurePenalty, Config.repeatedFailurePenaltyCap)

        let recoveries = window.filter { $0.isRecovery && $0.isDone }.count
        let bonus = min(Double(recoveries) * Config.recoveryPointBonus, Config.recoveryPointBonusCap)
            + min(Double(dayStreak(tasks, now: now)) * Config.streakPointBonus, Config.streakPointBonusCap)

        let score = Int(min(max(base - penalties + bonus, 0), 100).rounded())
        return Accountability(score: score, promisesKept: kept, productivity: productive, integrity: integrity,
                              onTime: onTime, penalties: penalties, bonus: bonus,
                              criticalLost: criticalLost, unexplained: unexplained)
    }
}
