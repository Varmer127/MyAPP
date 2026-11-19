import Foundation
import SwiftData

/// Tasks keep the name of a built-in activity ("Ostatní", "Práce", "Procházka v přírodě") as plain text, written
/// in the language of the day they were made. When the language changes, those names are rewritten in the new one,
/// so the task list, history, notifications and widgets all match. Names the user typed themselves stay as they are.
enum ActivityNames {
    private static let languageKey = "activityNamesLanguage"

    /// Every built-in name in the other languages, pointing to the same name in `language`.
    @MainActor
    static func translations(to language: AppLanguage) -> [String: String] {
        let target = names(in: language.rawValue)
        var map: [String: String] = [:]
        for code in KeptLanguage.codes where code != language.rawValue {
            for (key, name) in names(in: code) {
                if let wanted = target[key], wanted != name { map[name] = wanted }
            }
        }
        return map
    }

    /// The built-in names in one language, keyed by activity and kind.
    @MainActor
    private static func names(in code: String) -> [String: String] {
        let previous = LanguageBundle.fixedCode
        LanguageBundle.fixedCode = code
        defer { LanguageBundle.fixedCode = previous }
        var names: [String: String] = [:]
        for category in TaskCategory.allCases {
            names["\(category.rawValue).title"] = category.title
            names["\(category.rawValue).suggestion"] = category.suggestionTitle
        }
        return names
    }

    /// Rewrites stored names when they were written in another language than `language`. Cheap when nothing changed.
    @MainActor
    static func follow(_ language: AppLanguage, in context: ModelContext) {
        guard UserDefaults.standard.string(forKey: languageKey) != language.rawValue else { return }
        rename(with: translations(to: language), in: context)
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
    }

    @MainActor
    static func rename(with map: [String: String], in context: ModelContext) {
        guard !map.isEmpty else { return }
        for task in (try? context.fetch(FetchDescriptor<TaskItem>())) ?? [] {
            if let name = map[task.title] { task.title = name }
        }
        for record in (try? context.fetch(FetchDescriptor<FailureRecord>())) ?? [] {
            if let name = map[record.taskTitle] { record.taskTitle = name }
        }
        for entry in (try? context.fetch(FetchDescriptor<Postponement>())) ?? [] {
            if let name = map[entry.taskTitle] { entry.taskTitle = name }
        }
        for edit in (try? context.fetch(FetchDescriptor<CommitmentEdit>())) ?? [] {
            if let name = map[edit.taskTitle] { edit.taskTitle = name }
        }
        Persistence.save(context)
        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let plans = (try? context.fetch(FetchDescriptor<WeeklyPlan>())) ?? []
        WidgetBridge.update(tasks: tasks, plans: plans, targets: UserSettings.current(in: context).weeklyTargets)
    }
}
