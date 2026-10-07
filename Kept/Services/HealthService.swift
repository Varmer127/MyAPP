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
        let types: Set<HKObjectType> = [HKQuantityType(.bodyMass), HKObjectType.workoutType()]
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
}
