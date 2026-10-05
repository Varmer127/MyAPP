import Foundation

/// Ordered by default importance: long-term development first, sport and chores last.
enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case newSkill, building, work, education, reading, administration, gym, sport, nature, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newSkill: "Nový skill"
        case .building: "Claude a aplikace"
        case .work: "Práce"
        case .education: "Škola"
        case .reading: "Čtení"
        case .administration: "Administrativa"
        case .gym: "Gym"
        case .sport: "Sport"
        case .nature: "Příroda"
        case .other: "Ostatní"
        }
    }

    /// Multiplier applied to the priority's base points to get a task's default weight.
    var defaultMultiplier: Double {
        switch self {
        case .newSkill, .building, .work: 1.0
        case .education: 0.9
        case .reading: 0.75
        case .administration, .gym, .sport: 0.5
        case .nature, .other: 0.4
        }
    }

    var isHighValue: Bool { self == .newSkill || self == .building || self == .work || self == .education }

    /// How many times a week this category should happen by default. 0 = no weekly goal.
    var defaultWeeklyTarget: Int {
        switch self {
        case .gym: 4
        case .newSkill: 2
        case .reading, .nature: 1
        case .building, .work, .education, .administration, .sport, .other: 0
        }
    }

    var suggestionTitle: String {
        switch self {
        case .newSkill: "Naučit se něco nového"
        case .nature: "Procházka v přírodě"
        case .building: "Práce na aplikaci"
        default: title
        }
    }

    var suggestionMinutes: Int {
        switch self {
        case .reading: 30
        case .sport: 45
        default: 60
        }
    }
}

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low, medium, high, critical

    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: "Nízká"
        case .medium: "Střední"
        case .high: "Vysoká"
        case .critical: "Kritická"
        }
    }

    /// Short label shown on a task.
    var badge: String {
        switch self {
        case .low: "Nízká priorita"
        case .medium: "Střední priorita"
        case .high: "Vysoká priorita"
        case .critical: "Kritický"
        }
    }

    var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .critical: 3
        }
    }

    var basePoints: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 4
        case .critical: 5
        }
    }
}

enum TaskStatus: String, Codable {
    case pending, completed, completedLate, skipped, failed
}

enum FailureReason: String, CaseIterable, Identifiable, Codable {
    case forgot, procrastinated, lazy, didNotFeelLikeIt, plannedBadly, noTime, unexpected, health, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forgot: "Zapomněl jsem"
        case .procrastinated: "Prokrastinoval jsem"
        case .lazy: "Byl jsem líný"
        case .didNotFeelLikeIt: "Nechtělo se mi"
        case .plannedBadly: "Špatně jsem si to naplánoval"
        case .noTime: "Neměl jsem dost času"
        case .unexpected: "Nečekaná situace"
        case .health: "Zdraví"
        case .other: "Jiné"
        }
    }
}

enum FailureKind: String, Codable {
    /// The user actively gave up on the task.
    case skipped
    /// The day ended with the task still open.
    case missed
}

enum EditKind: String, Codable {
    case removed, moved, priorityLowered, priorityRaised, deadlineChanged, weightLowered, weightRaised, addedLater

    var title: String {
        switch self {
        case .removed: "Odstraněno"
        case .moved: "Přesunuto"
        case .priorityLowered: "Snížená priorita"
        case .priorityRaised: "Zvýšená priorita"
        case .deadlineChanged: "Změněný deadline"
        case .weightLowered: "Snížená váha"
        case .weightRaised: "Zvýšená váha"
        case .addedLater: "Přidáno po závazku"
        }
    }

    /// Share of one commitment that this kind of change costs in Commitment Integrity.
    var integrityPenalty: Double {
        switch self {
        case .removed: 1.0
        case .moved, .priorityLowered: 0.5
        case .deadlineChanged, .weightLowered: 0.25
        case .priorityRaised, .weightRaised, .addedLater: 0
        }
    }
}
