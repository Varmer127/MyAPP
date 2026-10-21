import Foundation

/// What the past says about an exercise: the last sets, the best so far and what to try next.
enum GymService {
    static let weightStep = 2.5
    /// From this many reps on, the next session should add weight rather than reps.
    static let repsBeforeAddingWeight = 8

    static func logs(of name: String, in tasks: [TaskItem], before date: Date = .distantFuture) -> [ExerciseLog] {
        tasks.flatMap(\.exercises)
            .filter { $0.name.activityKey == name.activityKey && $0.date < date }
            .sorted { $0.date > $1.date }
    }

    static func last(_ name: String, in tasks: [TaskItem], before date: Date = .distantFuture) -> ExerciseLog? {
        logs(of: name, in: tasks, before: date).first
    }

    /// Best estimated 1RM ever logged before `date`; 0 when there is no history.
    static func bestMax(_ name: String, in tasks: [TaskItem], before date: Date = .distantFuture) -> Double {
        logs(of: name, in: tasks, before: date).map(\.bestEstimatedMax).max() ?? 0
    }

    /// "Minule 80 kg × 8 → zkus 82,5 kg × 8". Nil without history or for bodyweight work.
    static func suggestion(for name: String, in tasks: [TaskItem]) -> String? {
        guard let last = last(name, in: tasks),
              let top = last.workingSets.filter({ ExerciseLog.plausibleWeight.contains($0.weight) }).max(by: { $0.weight < $1.weight }),
              top.weight > 0 else { return nil }
        if top.reps >= repsBeforeAddingWeight {
            return "Minule \(top.weight.kilogramText) × \(top.reps) → zkus \((top.weight + weightStep).kilogramText) × \(top.reps)"
        }
        return "Minule \(top.weight.kilogramText) × \(top.reps) → zkus \(top.weight.kilogramText) × \(top.reps + 1)"
    }
}
