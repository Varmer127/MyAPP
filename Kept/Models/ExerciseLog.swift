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
