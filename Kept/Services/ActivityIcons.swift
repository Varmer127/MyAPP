import Foundation
import Observation

/// The icon of each activity. Built-in activities start with their own icon and the user's own
/// activities with a star; any of them can be changed. Kept in the shared App Group defaults,
/// so every screen reads it cheaply and the widgets can show the same icons.
@Observable
final class ActivityIcons {
    static let shared = ActivityIcons()
    static let customDefault = "star"

    private static let key = "activityIcons"
    @ObservationIgnored private let defaults = UserDefaults(suiteName: "group.cz.philipstryka.kept") ?? .standard
    private(set) var chosen: [String: String]

    private init() {
        chosen = (defaults.dictionary(forKey: Self.key) as? [String: String]) ?? [:]
    }

    func symbol(for category: TaskCategory) -> String {
        chosen[Self.key(category)] ?? category.symbol
    }

    func symbol(forCustom name: String) -> String {
        chosen[Self.key(custom: name)] ?? Self.customDefault
    }

    /// A task named after one of the user's own activities shows that activity's icon.
    func symbol(for task: TaskItem) -> String {
        if task.category == .other, let custom = chosen[Self.key(custom: task.title)] { return custom }
        return symbol(for: task.category)
    }

    func set(_ symbol: String, for category: TaskCategory) {
        update(Self.key(category), symbol == category.symbol ? nil : symbol)
    }

    func set(_ symbol: String, forCustom name: String) {
        update(Self.key(custom: name), symbol)
    }

    func removeCustom(_ name: String) {
        update(Self.key(custom: name), nil)
    }

    /// Gives the user's own activities an icon entry, so tasks named after them show it.
    func register(custom names: [String]) {
        for name in names where chosen[Self.key(custom: name)] == nil {
            update(Self.key(custom: name), Self.customDefault)
        }
    }

    /// Writes the icons chosen in the first-launch guide.
    func apply(categories: [TaskCategory: String], custom: [String: String]) {
        for (category, symbol) in categories { set(symbol, for: category) }
        for (name, symbol) in custom { set(symbol, forCustom: name) }
    }

    func reset() {
        chosen = [:]
        defaults.removeObject(forKey: Self.key)
    }

    private func update(_ key: String, _ symbol: String?) {
        chosen[key] = symbol
        defaults.set(chosen, forKey: Self.key)
    }

    private static func key(_ category: TaskCategory) -> String { "category." + category.rawValue }
    private static func key(custom name: String) -> String { "custom." + name.activityKey }
}

extension TaskCategory {
    /// The icon the user sees: their choice, or the built-in one.
    var icon: String { ActivityIcons.shared.symbol(for: self) }
}

extension TaskItem {
    var icon: String { ActivityIcons.shared.symbol(for: self) }
}
