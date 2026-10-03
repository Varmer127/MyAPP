import Foundation
import SwiftData

/// Single-row settings store.
@Model
final class UserSettings {
    /// JSON-encoded `[TaskCategory.rawValue: Double]` overrides of the default category multipliers.
    var multipliersData: Data = Data()

    init() {}

    static let weightRange = 1...5

    private var overrides: [String: Double] {
        get { (try? JSONDecoder().decode([String: Double].self, from: multipliersData)) ?? [:] }
        set { multipliersData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func multiplier(for category: TaskCategory) -> Double {
        overrides[category.rawValue] ?? category.defaultMultiplier
    }

    func setMultiplier(_ value: Double, for category: TaskCategory) {
        overrides[category.rawValue] = value
    }

    func resetMultipliers() {
        overrides = [:]
    }

    func defaultWeight(category: TaskCategory, priority: TaskPriority) -> Int {
        UserSettings.weight(points: priority.basePoints, multiplier: multiplier(for: category))
    }

    static func weight(points: Int, multiplier: Double) -> Int {
        let raw = Int((Double(points) * multiplier).rounded())
        return min(max(raw, weightRange.lowerBound), weightRange.upperBound)
    }

    static func current(in context: ModelContext) -> UserSettings {
        if let existing = try? context.fetch(FetchDescriptor<UserSettings>()).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        return settings
    }
}
