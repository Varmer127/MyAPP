import Foundation
import HealthKit

/// Read-only access to Apple Health: body weight and workouts. Nothing is ever written.
enum HealthService {
    private static let store = HKHealthStore()
    private static let minimumWorkoutMinutes = 15.0
    /// Workout types that count as a gym session.
    private static let gymActivities: Set<HKWorkoutActivityType> = [
        .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining,
        .crossTraining, .highIntensityIntervalTraining, .mixedCardio,
    ]

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the system permission sheet. Health never tells an app whether reading was allowed,
    /// so `true` only means the request itself went through.
    static func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        let types: Set<HKObjectType> = [
            HKQuantityType(.bodyMass), HKObjectType.workoutType(),
            HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
        ]
        return (try? await store.requestAuthorization(toShare: [], read: types)) != nil
    }

    static func weights(since: Date) async -> [(date: Date, kilograms: Double)] {
        guard isAvailable else { return [] }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass),
                                         predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }

    static func weightToday(now: Date = .now) async -> Double? {
        await weights(since: now.startOfDay).last?.kilograms
    }

    /// Minutes of gym-type workouts recorded today, or nil if there were none worth counting.
    static func gymMinutesToday(now: Date = .now) async -> Int? {
        guard isAvailable else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: now.startOfDay, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let workouts = (try? await descriptor.result(for: store)) ?? []
        let minutes = workouts.filter { gymActivities.contains($0.workoutActivityType) }
            .reduce(0.0) { $0 + $1.duration / 60 }
        return minutes >= minimumWorkoutMinutes ? Int(minutes) : nil
    }

    // MARK: Summary tab

    /// What Health knows about one day.
    struct DayMetrics: Hashable {
        let day: Date
        var steps: Int
        var km: Double
        var kcal: Int
    }

    struct Summary {
        /// Oldest first, one entry per day up to and including today.
        var days: [DayMetrics] = []
        /// Newest first.
        var workouts: [(date: Date, name: String, minutes: Int)] = []
        var weights: [(date: Date, kilograms: Double)] = []

        var today: DayMetrics? { days.last }
        var stepsToday: Int? { today.flatMap { $0.steps > 0 ? $0.steps : nil } }
        var energyToday: Int? { today.flatMap { $0.kcal > 0 ? $0.kcal : nil } }

        var isEmpty: Bool {
            workouts.isEmpty && weights.isEmpty && !days.contains { $0.steps > 0 || $0.kcal > 0 || $0.km > 0 }
        }
    }

    /// How far back the Health tab and the health badges look.
    static let historyDays = 365
    private static let weightHistoryDays = 365

    /// Health is read at most this often, unless the user pulls the screen down.
    static let minimumRefreshInterval: TimeInterval = 5 * 60
    nonisolated(unsafe) private static var lastFetch: Date?
    nonisolated(unsafe) private static var lastSummary: Summary?

    static func summary(now: Date = .now, keptTrainingDays: Set<Date> = [], force: Bool = false) async -> Summary {
        guard isAvailable else { return Summary() }
        if !force, let lastFetch, let lastSummary, now.timeIntervalSince(lastFetch) < minimumRefreshInterval,
           lastSummary.days.last?.day == now.startOfDay {
            return lastSummary
        }
        let today = now.startOfDay
        let first = today.addingDays(-(historyDays - 1))

        let steps = await dailyTotals(.stepCount, unit: .count(), from: first, now: now)
        let distance = await dailyTotals(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: first, now: now)
        let energy = await dailyTotals(.activeEnergyBurned, unit: .kilocalorie(), from: first, now: now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: first, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = (try? await descriptor.result(for: store)) ?? []

        let summary = Summary(
            days: (0..<historyDays).map { offset in
                let day = first.addingDays(offset)
                return DayMetrics(day: day, steps: Int(steps[day] ?? 0), km: distance[day] ?? 0, kcal: Int(energy[day] ?? 0))
            },
            workouts: workouts.map { ($0.startDate, name(of: $0.workoutActivityType), Int($0.duration / 60)) },
            weights: await weights(since: today.addingDays(-weightHistoryDays)))
        HealthStats.remember(summary, keptTrainingDays: keptTrainingDays)
        lastFetch = now
        lastSummary = summary
        return summary
    }

    /// Per-day sums of a cumulative quantity, keyed by the start of each day.
    private static func dailyTotals(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit,
                                    from start: Date, now: Date) async -> [Date: Double] {
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(identifier),
                                       predicate: HKQuery.predicateForSamples(withStart: start, end: now)),
            options: .cumulativeSum,
            anchorDate: start.startOfDay,
            intervalComponents: DateComponents(day: 1))
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var totals: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: now) { statistics, _ in
            totals[statistics.startDate.startOfDay] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return totals
    }

    private static func name(of activity: HKWorkoutActivityType) -> String {
        switch activity {
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Silový trénink"
        case .coreTraining: "Střed těla"
        case .highIntensityIntervalTraining: "HIIT"
        case .crossTraining, .mixedCardio: "Kardio"
        case .running: "Běh"
        case .walking: "Chůze"
        case .hiking: "Turistika"
        case .cycling: "Kolo"
        case .swimming: "Plavání"
        case .yoga: "Jóga"
        default: "Trénink"
        }
    }

    // MARK: Workout notification

    private static var workoutObserver: HKObserverQuery?
    private static let notifiedDayKey = "healthWorkoutNotifiedDay"
    private static let loggedGymDayKey = "healthLoggedGymDay"

    /// Remembers whether a gym workout was already logged today, so the observer below does not nag about it.
    static func noteGymLogged(_ isLogged: Bool, now: Date = .now) {
        UserDefaults.standard.set(isLogged ? now.daySeed : 0, forKey: loggedGymDayKey)
    }

    /// Watches Health for new workouts and sends one notification a day when a gym workout shows up
    /// that has not been logged in the app yet — whether or not a gym task was planned. Health records a workout when it is saved — normally at its end —
    /// and iOS decides when to wake the app, so the notification follows the workout, it does not start it.
    static func startWorkoutObserver() {
        guard isAvailable, workoutObserver == nil else { return }
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { _, completion, _ in
            Task {
                await notifyAboutTodaysWorkout()
                completion()
            }
        }
        workoutObserver = query
        store.execute(query)
        store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { _, _ in }
    }

    private static func notifyAboutTodaysWorkout(now: Date = .now) async {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: loggedGymDayKey) != now.daySeed,
              defaults.integer(forKey: notifiedDayKey) != now.daySeed,
              let minutes = await gymMinutesToday(now: now) else { return }
        defaults.set(now.daySeed, forKey: notifiedDayKey)
        await NotificationManager.notifyWorkoutDetected(minutes: minutes)
    }
}


/// The best Health results ever seen, kept between runs so a health badge, once earned, stays earned.
struct HealthStats: Codable, Equatable {
    var maxSteps = 0
    var maxKm = 0.0
    var maxKcal = 0
    /// Most days with a workout in one week. A workout is one recorded by Health (20 minutes or more) or a finished
    /// workout task in Kept; two on the same day count once, so a workout logged in both places is not counted twice.
    /// (Kept under its old name: `bestWeekWorkouts`.)
    /// Longest run of days in a row with at least 10 000 / 20 000 steps.
    var run10k = 0
    var run20k = 0
    var bestWeekKm = 0.0
    var bestWeekWorkouts = 0

    static let key = "healthStats"
    static let minimumWorkoutMinutes = 20

    static var stored: HealthStats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(HealthStats.self, from: data) else { return HealthStats() }
        return stats
    }

    func merged(with other: HealthStats) -> HealthStats {
        HealthStats(maxSteps: max(maxSteps, other.maxSteps), maxKm: max(maxKm, other.maxKm), maxKcal: max(maxKcal, other.maxKcal),
                    run10k: max(run10k, other.run10k), run20k: max(run20k, other.run20k),
                    bestWeekKm: max(bestWeekKm, other.bestWeekKm), bestWeekWorkouts: max(bestWeekWorkouts, other.bestWeekWorkouts))
    }

    static func from(_ summary: HealthService.Summary, keptTrainingDays: Set<Date> = []) -> HealthStats {
        var stats = HealthStats()
        var run10 = 0, run20 = 0
        for day in summary.days {
            stats.maxSteps = max(stats.maxSteps, day.steps)
            stats.maxKm = max(stats.maxKm, day.km)
            stats.maxKcal = max(stats.maxKcal, day.kcal)
            run10 = day.steps >= 10_000 ? run10 + 1 : 0
            run20 = day.steps >= 20_000 ? run20 + 1 : 0
            stats.run10k = max(stats.run10k, run10)
            stats.run20k = max(stats.run20k, run20)
        }
        for (_, days) in Dictionary(grouping: summary.days, by: { $0.day.weekStart }) {
            stats.bestWeekKm = max(stats.bestWeekKm, days.reduce(0) { $0 + $1.km })
        }
        stats.bestWeekWorkouts = bestWeekOfTraining(
            healthDays: Set(summary.workouts.filter { $0.minutes >= minimumWorkoutMinutes }.map { $0.date.startOfDay }),
            keptDays: keptTrainingDays)
        return stats
    }

    /// The week with the most distinct training days, from both sources together.
    static func bestWeekOfTraining(healthDays: Set<Date>, keptDays: Set<Date>) -> Int {
        let days = healthDays.union(keptDays.map(\.startOfDay))
        return Dictionary(grouping: days, by: \.weekStart).values.map(\.count).max() ?? 0
    }

    /// Folds a fresh summary into what was stored before.
    static func remember(_ summary: HealthService.Summary, keptTrainingDays: Set<Date> = []) {
        guard !summary.isEmpty else { return }
        save(stored.merged(with: .from(summary, keptTrainingDays: keptTrainingDays)))
    }

    /// Training done in Kept counts toward the badges even when Health is not connected.
    static func remember(keptTrainingDays: Set<Date>) {
        var stats = HealthStats()
        stats.bestWeekWorkouts = bestWeekOfTraining(healthDays: [], keptDays: keptTrainingDays)
        save(stored.merged(with: stats))
    }

    private static func save(_ merged: HealthStats) {
        guard merged != stored, let data = try? JSONEncoder().encode(merged) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

#if DEBUG
extension HealthService {
    /// A made-up year of Health data for trying the Health tab out on a simulator that has none. Developer test only.
    static func demoSummary(now: Date = .now) -> Summary {
        let today = now.startOfDay
        let first = today.addingDays(-(historyDays - 1))
        let days = (0..<historyDays).map { offset -> DayMetrics in
            let day = first.addingDays(offset)
            let seed = abs(day.daySeed)
            let wobble = [0.55, 0.9, 1.25, 0.7, 1.05, 0.8, 1.45, 0.6, 1.15]
            var steps = Int(7_000 * wobble[(offset * 5) % wobble.count]) + seed % 700
            // A few big days and one run of three, so the badges have something to show.
            if offset % 53 == 0 { steps = 21_000 + seed % 6_000 }
            if (330...332).contains(offset) { steps = 20_500 + seed % 3_000 }
            if offset == historyDays - 1 { steps = 6_240 }
            let km = Double(steps) * 0.00075
            return DayMetrics(day: day, steps: steps, km: km, kcal: Int(Double(steps) * 0.045) + seed % 150)
        }
        let names = ["Silový trénink", "Běh", "Chůze", "Kolo", "Jóga"]
        let workouts = (0..<40).map { index -> (date: Date, name: String, minutes: Int) in
            let date = today.addingDays(-index * 2 - 1).addingTimeInterval(18 * 3600)
            return (date, names[index % names.count], 25 + (index * 7) % 50)
        }
        let weights = (0..<24).map { index -> (date: Date, kilograms: Double) in
            (today.addingDays(-(23 - index) * 15), 84.0 - Double(index) * 0.18 + Double(index % 3) * 0.3)
        }
        return Summary(days: days, workouts: workouts, weights: weights)
    }
}
#endif
