import Foundation

/// Ordered by default importance: long-term development first, sport and chores last.
enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case newSkill, building, work, education, reading, administration, gym, sport, nature, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newSkill: String(localized: "Nový skill", bundle: .kept)
        case .building: String(localized: "Vlastní projekt", bundle: .kept)
        case .work: String(localized: "Práce", bundle: .kept)
        case .education: String(localized: "Škola", bundle: .kept)
        case .reading: String(localized: "Čtení", bundle: .kept)
        case .administration: String(localized: "Administrativa", bundle: .kept)
        case .gym: String(localized: "Gym", bundle: .kept)
        case .sport: String(localized: "Sport", bundle: .kept)
        case .nature: String(localized: "Příroda", bundle: .kept)
        case .other: String(localized: "Ostatní", bundle: .kept)
        }
    }

    /// SF Symbol shown next to the category name.
    var symbol: String {
        switch self {
        case .newSkill: "lightbulb"
        case .building: "hammer"
        case .work: "briefcase"
        case .education: "graduationcap"
        case .reading: "book"
        case .administration: "doc.text"
        case .gym: "dumbbell"
        case .sport: "figure.run"
        case .nature: "leaf"
        case .other: "circle.grid.2x2"
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
        case .newSkill: String(localized: "Naučit se něco nového", bundle: .kept)
        case .nature: String(localized: "Procházka v přírodě", bundle: .kept)
        case .building: String(localized: "Práce na projektu", bundle: .kept)
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
        case .low: String(localized: "Nízká", bundle: .kept)
        case .medium: String(localized: "Střední", bundle: .kept)
        case .high: String(localized: "Vysoká", bundle: .kept)
        case .critical: String(localized: "Kritická", bundle: .kept)
        }
    }

    /// Short label shown on a task.
    var badge: String {
        switch self {
        case .low: String(localized: "Nízká priorita", bundle: .kept)
        case .medium: String(localized: "Střední priorita", bundle: .kept)
        case .high: String(localized: "Vysoká priorita", bundle: .kept)
        case .critical: String(localized: "Kritický", bundle: .kept)
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
    /// Cancelled with a points pass: closed, but left out of every score.
    case excused
}

enum FailureReason: String, CaseIterable, Identifiable, Codable {
    case forgot, procrastinated, lazy, didNotFeelLikeIt, plannedBadly, noTime, unexpected, health, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forgot: String(localized: "Zapomněl jsem", bundle: .kept)
        case .procrastinated: String(localized: "Prokrastinoval jsem", bundle: .kept)
        case .lazy: String(localized: "Byl jsem líný", bundle: .kept)
        case .didNotFeelLikeIt: String(localized: "Nechtělo se mi", bundle: .kept)
        case .plannedBadly: String(localized: "Špatně jsem si to naplánoval", bundle: .kept)
        case .noTime: String(localized: "Neměl jsem dost času", bundle: .kept)
        case .unexpected: String(localized: "Nečekaná situace", bundle: .kept)
        case .health: String(localized: "Zdraví", bundle: .kept)
        case .other: String(localized: "Jiné", bundle: .kept)
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
        case .removed: String(localized: "Odstraněno", bundle: .kept)
        case .moved: String(localized: "Přesunuto", bundle: .kept)
        case .priorityLowered: String(localized: "Snížená priorita", bundle: .kept)
        case .priorityRaised: String(localized: "Zvýšená priorita", bundle: .kept)
        case .deadlineChanged: String(localized: "Změněný deadline", bundle: .kept)
        case .weightLowered: String(localized: "Snížená váha", bundle: .kept)
        case .weightRaised: String(localized: "Zvýšená váha", bundle: .kept)
        case .addedLater: String(localized: "Přidáno po závazku", bundle: .kept)
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
