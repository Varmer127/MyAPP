import Foundation
import SwiftData

/// Single-row settings store.
@Model
final class UserSettings {
    /// JSON-encoded `[TaskCategory.rawValue: Double]` overrides of the default category multipliers.
    var multipliersData: Data = Data()

    var toneRaw: String = NotificationTone.strict.rawValue
    var taskRemindersEnabled: Bool = true
    var sundayRemindersEnabled: Bool = true
    var morningBriefEnabled: Bool = true
    var realityCheckEnabled: Bool = true
    /// Minutes after midnight.
    var morningBriefMinutes: Int = 7 * 60 + 30
    var realityCheckMinutes: Int = 21 * 60 + 30
    var sundayStartHour: Int = 10
    var sundayEndHour: Int = 21
    /// Gap between repeated reminders once a deadline has passed.
    var overdueRepeatMinutes: Int = 45

    /// JSON-encoded `[TaskCategory.rawValue: Int]` overrides of the default weekly targets.
    var weeklyTargetsData: Data = Data()
    /// JSON-encoded `[String]` of gym workout presets. Empty data means "never edited".
    var workoutPresetsData: Data = Data()

    init() {}

    static let defaultWorkoutPresets = ["Ruce a ramena", "Záda a prsa", "Nohy"]
    static let weeklyTargetRange = 0...7

    private var targetOverrides: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: weeklyTargetsData)) ?? [:] }
        set { weeklyTargetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func weeklyTarget(for category: TaskCategory) -> Int {
        targetOverrides[category.rawValue] ?? category.defaultWeeklyTarget
    }

    func setWeeklyTarget(_ value: Int, for category: TaskCategory) {
        targetOverrides[category.rawValue] = value
    }

    var workoutPresets: [String] {
        get {
            guard !workoutPresetsData.isEmpty else { return UserSettings.defaultWorkoutPresets }
            return (try? JSONDecoder().decode([String].self, from: workoutPresetsData)) ?? UserSettings.defaultWorkoutPresets
        }
        set { workoutPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var tone: NotificationTone {
        get { NotificationTone(rawValue: toneRaw) ?? .strict }
        set { toneRaw = newValue.rawValue }
    }

    /// Changes whenever anything that affects scheduled notifications changes.
    var notificationSignature: Int {
        var hasher = Hasher()
        hasher.combine(toneRaw)
        hasher.combine([taskRemindersEnabled, sundayRemindersEnabled, morningBriefEnabled, realityCheckEnabled])
        hasher.combine([morningBriefMinutes, realityCheckMinutes, sundayStartHour, sundayEndHour, overdueRepeatMinutes])
        return hasher.finalize()
    }

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
