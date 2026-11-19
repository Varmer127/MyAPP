import Foundation
import SwiftData

/// Everything chosen in the first-launch guide. Nothing is stored until the guide is finished;
/// whatever was skipped keeps the app's defaults.
struct OnboardingDraft {
    enum Split: String, CaseIterable, Identifiable {
        case pushPullLegs, upperLower, fullBody, own
        var id: String { rawValue }

        var title: String {
            switch self {
            case .pushPullLegs: "Push / Pull / Legs"
            case .upperLower: String(localized: "Horní / Spodní", bundle: .kept)
            case .fullBody: String(localized: "Full body", bundle: .kept)
            case .own: String(localized: "Vlastní split", bundle: .kept)
            }
        }

        var summary: String {
            switch self {
            case .pushPullLegs: String(localized: "Tlaky, tahy, nohy", bundle: .kept)
            case .upperLower: String(localized: "Vršek a spodek těla střídavě", bundle: .kept)
            case .fullBody: String(localized: "Celé tělo při každém tréninku", bundle: .kept)
            case .own: String(localized: "Tréninky si pojmenuješ sám", bundle: .kept)
            }
        }

        /// The workouts offered when logging a gym session.
        var workouts: [String] {
            switch self {
            case .pushPullLegs: [String(localized: "Push (tlaky)", bundle: .kept), String(localized: "Pull (tahy)", bundle: .kept), String(localized: "Legs (nohy)", bundle: .kept)]
            case .upperLower: [String(localized: "Horní polovina", bundle: .kept), String(localized: "Spodní polovina", bundle: .kept)]
            case .fullBody: [String(localized: "Full body", bundle: .kept)]
            case .own: []
            }
        }
    }

    /// Offered in the guide, in this order. "Ostatní" is always there and not offered.
    static let offeredCategories: [TaskCategory] = [.gym, .reading, .newSkill, .nature, .work, .education, .sport, .building, .administration]

    var activities: Set<TaskCategory> = [.gym, .reading, .newSkill, .nature]
    var customActivities: [String] = []
    /// Icons changed in the guide; everything else keeps its default.
    var categoryIcons: [TaskCategory: String] = [:]
    var customIcons: [String: String] = [:]
    var minimum = UserSettings.defaultMinimumWeeklyTasks
    var addressName = ""
    var grammar: GrammarGender = .neutral
    var gymMode: GymMode = .simple
    var split: Split = .pushPullLegs
    var ownWorkouts = [String(localized: "Hrudník a triceps", bundle: .kept), String(localized: "Záda a biceps", bundle: .kept), String(localized: "Nohy", bundle: .kept)]
    var gymPerWeek = TaskCategory.gym.defaultWeeklyTarget
    var restName = RestPreset.defaults[1].name
    var health = false
    var diary = true
    var diaryLock = false
    var appLock = false
    var tabs: [AppTab] = [.stats, .gym]
    var tone: NotificationTone = .strict
    var morningMinutes = 7 * 60 + 30
    var eveningMinutes = 21 * 60 + 30
    var sundayStartHour = 10

    var doesGym: Bool { activities.contains(.gym) }

    func icon(for category: TaskCategory) -> String { categoryIcons[category] ?? category.symbol }
    func icon(forCustom name: String) -> String { customIcons[name] ?? ActivityIcons.customDefault }

    /// Names of everything chosen, as the user would read them.
    var activityNames: [String] {
        Self.offeredCategories.filter { activities.contains($0) }.map(\.title) + customActivities
    }

    /// An activity to use in examples, preferring something that is not the gym.
    var exampleActivity: String {
        activityNames.first { $0 != TaskCategory.gym.title } ?? activityNames.first ?? TaskCategory.reading.title
    }

    var secondExampleActivity: String {
        activityNames.first { $0 != exampleActivity && $0 != TaskCategory.gym.title } ?? TaskCategory.nature.suggestionTitle
    }

    /// Writes the choices into the settings and marks the guide as done.
    func apply(to settings: UserSettings, now: Date = .now) {
        settings.addressName = addressName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.grammar = grammar
        settings.enabledCategories = Array(activities) + [.other]
        settings.customActivities = customActivities
        ActivityIcons.shared.apply(categories: categoryIcons, custom: customIcons.filter { customActivities.contains($0.key) })
        ActivityIcons.shared.register(custom: customActivities)
        settings.minimumWeeklyTasks = minimum

        if doesGym {
            let workouts = split == .own
                ? ownWorkouts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                : split.workouts
            if !workouts.isEmpty { settings.workoutPresets = workouts }
            settings.setWeeklyTarget(gymPerWeek, for: .gym)
            settings.gymMode = gymMode
            // The chosen rest goes to the top, which makes it the stopwatch's default.
            let presets = settings.restPresets
            if let chosen = presets.first(where: { $0.name == restName }) {
                settings.restPresets = [chosen] + presets.filter { $0 != chosen }
            }
        }

        settings.healthEnabled = health
        settings.diaryEnabled = diary
        settings.diaryLockEnabled = diary && diaryLock
        settings.appLockEnabled = appLock

        settings.showsStatsTab = tabs.contains(.stats)
        settings.showsGymTab = tabs.contains(.gym) && doesGym
        settings.showsHealthTab = tabs.contains(.health)
        settings.showsDiaryTab = tabs.contains(.diary) && diary

        settings.tone = tone
        settings.morningBriefMinutes = morningMinutes
        settings.realityCheckMinutes = eveningMinutes
        settings.sundayStartHour = min(sundayStartHour, settings.sundayEndHour)
        settings.onboardedAt = now
    }
}
