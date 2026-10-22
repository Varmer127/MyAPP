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
    /// Warnings before the day streak breaks and reminders after it did.
    var streakRemindersEnabled: Bool = true
    /// Minutes after midnight.
    var morningBriefMinutes: Int = 7 * 60 + 30
    var realityCheckMinutes: Int = 21 * 60 + 30
    var sundayStartHour: Int = 10
    var sundayEndHour: Int = 21
    /// Gap between repeated reminders once a deadline has passed.
    var overdueRepeatMinutes: Int = 45
    /// How many times a day Kept reminds about open tasks that have no deadline (0 = never).
    var nudgesPerDay: Int = 3
    /// The part of the day those reminders stay inside, in minutes after midnight.
    var nudgeFromMinutes: Int = 10 * 60
    var nudgeToMinutes: Int = 20 * 60
    /// Daily step goal shown in the Health tab.
    var stepGoal: Int = 8000

    /// JSON-encoded `[TaskCategory.rawValue: Int]` overrides of the default weekly targets.
    var weeklyTargetsData: Data = Data()
    /// JSON-encoded `[String]` of gym workout presets. Empty data means "never edited".
    var workoutPresetsData: Data = Data()
    /// JSON-encoded `[String]` of gym exercise presets. Empty data means "never edited".
    var exercisePresetsData: Data = Data()
    /// JSON-encoded `[RestPreset]`. Empty data means "never edited".
    var restPresetsData: Data = Data()
    /// Fewest activities a weekly plan must contain. 0 turns the rule off.
    var minimumWeeklyTasks: Int = 7
    /// How many tasks a month may be postponed without penalty. Can only be lowered below the maximum.
    var postponeLimit: Int = 3
    var healthEnabled: Bool = false
    /// Show the iPhone calendar's events next to the plan and warn about clashes.
    var calendarEnabled: Bool = false

    // Optional tabs. Dnes, Týden and Nastavení are always shown.
    var showsStatsTab: Bool = true
    var showsGymTab: Bool = false
    var showsHealthTab: Bool = false
    var showsDiaryTab: Bool = false
    /// Microphone button next to the diary's text fields.
    var diaryVoiceEnabled: Bool = false
    /// The diary opens only after Face ID / the passcode.
    var diaryLockEnabled: Bool = false
    /// The diary exists at all. Off hides it everywhere.
    var diaryEnabled: Bool = true
    /// The whole app opens only after Face ID / the passcode.
    var appLockEnabled: Bool = false
    /// JSON-encoded `[TaskCategory.rawValue]` the user does. Empty data means "never chosen": everything is on.
    var enabledCategoriesData: Data = Data()
    /// JSON-encoded `[String]`: the user's own activities, planned under "Ostatní".
    var customActivitiesData: Data = Data()
    /// JSON-encoded `[workout name: [exercise names]]`, the exercises a workout starts with.
    var workoutTemplatesData: Data = Data()
    /// When the first-launch guide was finished. Nil shows it.
    var onboardedAt: Date?
    /// How the user wants to be called in greetings, exactly as it should read ("Filipe", "Anežko", "Franto").
    /// Typed by the user, because the Czech vocative cannot be derived reliably from a name.
    var addressName: String = ""
    var grammarRaw: String = GrammarGender.neutral.rawValue
    /// How much the gym section records. Existing installs keep the full version they already use.
    var gymModeRaw: String = GymMode.advanced.rawValue

    init() {}

    /// Categories the user picked as theirs. "Ostatní" is always available for one-off tasks.
    var enabledCategories: [TaskCategory] {
        get {
            guard !enabledCategoriesData.isEmpty,
                  let raw = try? JSONDecoder().decode([String].self, from: enabledCategoriesData) else { return TaskCategory.allCases }
            return TaskCategory.allCases.filter { raw.contains($0.rawValue) || $0 == .other }
        }
        set { enabledCategoriesData = (try? JSONEncoder().encode(newValue.map(\.rawValue))) ?? Data() }
    }

    func isEnabled(_ category: TaskCategory) -> Bool { enabledCategories.contains(category) }

    func setEnabled(_ enabled: Bool, _ category: TaskCategory) {
        var list = enabledCategories.filter { $0 != category }
        if enabled { list.append(category) }
        enabledCategories = list
    }

    /// The exercises a workout starts with: the user's own list, else a ready-made one for its name.
    func template(for workout: String) -> [String] {
        let own = (try? JSONDecoder().decode([String: [String]].self, from: workoutTemplatesData)) ?? [:]
        return own[workout] ?? ExerciseCatalog.defaultTemplate(for: workout)
    }

    func setTemplate(_ exercises: [String], for workout: String) {
        var own = (try? JSONDecoder().decode([String: [String]].self, from: workoutTemplatesData)) ?? [:]
        own[workout] = exercises
        workoutTemplatesData = (try? JSONEncoder().encode(own)) ?? Data()
    }

    var customActivities: [String] {
        get { (try? JSONDecoder().decode([String].self, from: customActivitiesData)) ?? [] }
        set { customActivitiesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// JSON-encoded `[String]`: the `activityKey` of every custom activity the user counts as a workout.
    var sportActivitiesData: Data = Data()

    var sportActivityKeys: Set<String> {
        get { Set((try? JSONDecoder().decode([String].self, from: sportActivitiesData)) ?? []) }
        set { sportActivitiesData = (try? JSONEncoder().encode(newValue.sorted())) ?? Data() }
    }

    func countsAsWorkout(custom name: String) -> Bool { sportActivityKeys.contains(name.activityKey) }

    func setCountsAsWorkout(_ on: Bool, custom name: String) {
        var keys = sportActivityKeys
        if on { keys.insert(name.activityKey) } else { keys.remove(name.activityKey) }
        sportActivityKeys = keys
    }

    /// Gym and sport always are workouts; a custom activity is one when the user said so.
    func isWorkout(_ task: TaskItem) -> Bool {
        switch task.category {
        case .gym, .sport: true
        case .other: countsAsWorkout(custom: task.title)
        default: false
        }
    }

    static let defaultWorkoutPresets = ["Ruce a ramena", "Záda a prsa", "Nohy"]
    static let defaultExercisePresets = ["Bench press", "Dřep", "Mrtvý tah", "Tlaky nad hlavu", "Shyby", "Přítahy v předklonu"]

    var restPresets: [RestPreset] {
        get {
            guard !restPresetsData.isEmpty,
                  let stored = try? JSONDecoder().decode([RestPreset].self, from: restPresetsData),
                  !stored.isEmpty else { return RestPreset.defaults }
            return stored
        }
        set { restPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var exercisePresets: [String] {
        get {
            guard !exercisePresetsData.isEmpty else { return UserSettings.defaultExercisePresets }
            return (try? JSONDecoder().decode([String].self, from: exercisePresetsData)) ?? UserSettings.defaultExercisePresets
        }
        set { exercisePresetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    static let weeklyTargetRange = 0...7
    static let minimumWeeklyTasksRange = 0...40
    static let postponeLimitRange = 0...3
    /// iOS shows five tabs before collapsing the rest under "More"; three are fixed.
    static let maxOptionalTabs = 2

    var optionalTabCount: Int { [showsStatsTab, showsGymTab, showsHealthTab, showsDiaryTab && diaryEnabled].filter { $0 }.count }
    static let defaultMinimumWeeklyTasks = 7

    private var targetOverrides: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: weeklyTargetsData)) ?? [:] }
        set { weeklyTargetsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Every category's rough weekly target, for scoring.
    var weeklyTargets: [TaskCategory: Int] {
        Dictionary(uniqueKeysWithValues: TaskCategory.allCases.map { ($0, weeklyTarget(for: $0)) })
    }

    /// How many times a week the user roughly wants to do this. A category they do not do has no target.
    func weeklyTarget(for category: TaskCategory) -> Int {
        guard isEnabled(category) else { return 0 }
        return targetOverrides[category.rawValue] ?? category.defaultWeeklyTarget
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

    var grammar: GrammarGender {
        get { GrammarGender(rawValue: grammarRaw) ?? .neutral }
        set { grammarRaw = newValue.rawValue }
    }

    var gymMode: GymMode {
        get { GymMode(rawValue: gymModeRaw) ?? .advanced }
        set { gymModeRaw = newValue.rawValue }
    }

    var tone: NotificationTone {
        get { NotificationTone(rawValue: toneRaw) ?? .strict }
        set { toneRaw = newValue.rawValue }
    }

    /// Changes whenever anything that affects scheduled notifications changes.
    var notificationSignature: Int {
        var hasher = Hasher()
        hasher.combine(toneRaw)
        hasher.combine([taskRemindersEnabled, sundayRemindersEnabled, morningBriefEnabled, realityCheckEnabled, streakRemindersEnabled])
        hasher.combine([morningBriefMinutes, realityCheckMinutes, sundayStartHour, sundayEndHour, overdueRepeatMinutes])
        hasher.combine([nudgesPerDay, nudgeFromMinutes, nudgeToMinutes])
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

/// A named rest length between sets. People disagree on what is right, so the list is the user's to edit.
struct RestPreset: Codable, Hashable, Identifiable {
    var name: String
    var seconds: Int

    var id: String { name }

    static let secondsRange = 15...600
    static let secondsStep = 15

    static let defaults = [
        RestPreset(name: "Síla", seconds: 180),
        RestPreset(name: "Svaly", seconds: 90),
        RestPreset(name: "Vytrvalost", seconds: 30),
    ]
}

/// Simple records a workout with a stopwatch and rests; advanced adds exercises, sets, records and the muscle map.
/// Switching never deletes anything: advanced data only stays out of sight in the simple mode.
enum GymMode: String, CaseIterable, Identifiable {
    case simple, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: "Jednoduchý"
        case .advanced: "Pokročilý"
        }
    }

    var summary: String {
        switch self {
        case .simple: "Stopky tréninku a pauzy. Zapíšeš, co jsi jel, a hotovo."
        case .advanced: "Cviky, série, váhy a opakování, rekordy, šablony a mapa svalů."
        }
    }

    var features: [String] {
        switch self {
        case .simple: ["Stopky celého tréninku", "Odpočet pauzy jedním klepnutím", "Co jsi jel a počet tréninků týdně"]
        case .advanced: ["Cviky série po sérii, s čísly z minula", "Knihovna cviků s mapou svalů", "Rekordy, síla v čase a týdenní mapa svalů", "Šablony tréninků a rozcvičky"]
        }
    }
}

/// Which verb forms Kept uses when it talks about the user ("splnil" / "splnila" / "splnil(a)").
/// The neutral choice avoids gendered forms where a sentence can be written without them.
enum GrammarGender: String, CaseIterable, Identifiable {
    case masculine, feminine, neutral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .masculine: "Mužský rod"
        case .feminine: "Ženský rod"
        case .neutral: "Neutrálně"
        }
    }

    var example: String {
        switch self {
        case .masculine: "„Splnil jsi to.“"
        case .feminine: "„Splnila jsi to.“"
        case .neutral: "„To je splněno.“"
        }
    }

    /// Picks the form that matches; the neutral one is used when it differs from both.
    func pick(_ masculine: String, _ feminine: String, neutral: String? = nil) -> String {
        switch self {
        case .masculine: masculine
        case .feminine: feminine
        case .neutral: neutral ?? "\(masculine)(a)"
        }
    }
}
