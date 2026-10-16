import Foundation
import SwiftData

/// One exercise done in a gym workout: the working weight, repetitions and number of sets.
@Model
final class ExerciseLog {
    var date: Date = Date()
    var name: String = ""
    /// Weight on the bar in kg; 0 means bodyweight.
    var weight: Double = 0
    var reps: Int = 0
    var sets: Int = 1
    var task: TaskItem?
    /// Every set as it was done, warm-ups included. Empty for workouts logged before sets existed.
    @Relationship(deleteRule: .cascade, inverse: \SetLog.log)
    var setLogs: [SetLog] = []

    init(name: String, weight: Double, reps: Int, sets: Int, date: Date = .now) {
        self.name = name
        self.weight = weight
        self.reps = reps
        self.sets = sets
        self.date = date
    }

    /// Estimated one-rep maximum (Epley formula) — lets sets with different rep counts be compared.
    static func estimatedMax(weight: Double, reps: Int) -> Double {
        reps <= 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    /// "80 kg × 8 · 3 série"
    var summary: String {
        let load = weight > 0 ? weight.kilogramText : "vlastní váha"
        return "\(load) × \(reps) · sérií: \(sets)"
    }
}

/// One set of an exercise. Warm-ups are kept but never count for volume, records or the summary.
@Model
final class SetLog {
    var order: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var isWarmup: Bool = false
    /// Ticked off in the live workout. Sets left unticked are dropped when the workout ends.
    var isDone: Bool = false
    var log: ExerciseLog?

    init(order: Int, weight: Double, reps: Int, isWarmup: Bool) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isWarmup = isWarmup
    }
}

extension ExerciseLog {
    /// Sets in the order they were done.
    var orderedSets: [SetLog] { setLogs.sorted { $0.order < $1.order } }

    /// Working sets only; for older logs without sets, the summary stands in for them.
    var workingSets: [(weight: Double, reps: Int)] {
        let logged = orderedSets.filter { !$0.isWarmup && $0.isDone }.map { (weight: $0.weight, reps: $0.reps) }
        return logged.isEmpty ? Array(repeating: (weight: weight, reps: reps), count: max(sets, 1)) : logged
    }

    /// Best estimated one-rep maximum of the working sets.
    var bestEstimatedMax: Double {
        workingSets.map { ExerciseLog.estimatedMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }

    /// Weight × reps summed over the working sets.
    var volume: Double { workingSets.reduce(0) { $0 + $1.weight * Double($1.reps) } }
}

extension ExerciseLog {
    /// After the live workout: drops unticked sets and writes the summary fields from the working sets.
    /// Returns false when nothing of the exercise was done, so the caller can remove it.
    @discardableResult
    func settle() -> Bool {
        for set in setLogs where !set.isDone {
            modelContext?.delete(set)
        }
        let done = orderedSets.filter { $0.isDone && !$0.isWarmup }
        guard let top = done.max(by: { ExerciseLog.estimatedMax(weight: $0.weight, reps: $0.reps)
            < ExerciseLog.estimatedMax(weight: $1.weight, reps: $1.reps) }) else { return false }
        weight = top.weight
        reps = top.reps
        sets = done.count
        return true
    }
}
