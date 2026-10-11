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

    struct Summary {
        var stepsToday: Int?
        var energyToday: Int?
        var dailySteps: [(day: Date, steps: Int)] = []
        var workouts: [(date: Date, name: String, minutes: Int)] = []
        var weights: [(date: Date, kilograms: Double)] = []

        var isEmpty: Bool {
            stepsToday == nil && energyToday == nil && workouts.isEmpty && weights.isEmpty
                && !dailySteps.contains { $0.steps > 0 }
        }
    }

    private static let summaryDays = 7
    private static let weightHistoryDays = 90

    static func summary(now: Date = .now) async -> Summary {
        guard isAvailable else { return Summary() }
        let today = now.startOfDay
        let weekAgo = today.addingDays(-(summaryDays - 1))

        let steps = await dailyTotals(.stepCount, unit: .count(), from: weekAgo, now: now)
        let energy = await dailyTotals(.activeEnergyBurned, unit: .kilocalorie(), from: today, now: now)

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: weekAgo, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)])
        let workouts = (try? await descriptor.result(for: store)) ?? []

        return Summary(
            stepsToday: steps[today].flatMap { $0 > 0 ? Int($0) : nil },
            energyToday: energy[today].flatMap { $0 > 0 ? Int($0) : nil },
            dailySteps: (0..<summaryDays).map { offset in
                let day = weekAgo.addingDays(offset)
                return (day, Int(steps[day] ?? 0))
            },
            workouts: workouts.map { ($0.startDate, name(of: $0.workoutActivityType), Int($0.duration / 60)) },
            weights: await weights(since: today.addingDays(-weightHistoryDays)))
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
