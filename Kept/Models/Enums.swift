import Foundation

/// Ordered by default importance: long-term development first, sport and chores last.
enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case selfDevelopment, work, education, reading, administration, sport, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfDevelopment: "Self Development"
        case .work: "Work"
        case .education: "School"
        case .reading: "Reading"
        case .administration: "Administration"
        case .sport: "Sport"
        case .other: "Other"
        }
    }

    /// Multiplier applied to the priority's base points to get a task's default weight.
    var defaultMultiplier: Double {
        switch self {
        case .selfDevelopment, .work: 1.0
        case .education: 0.9
        case .reading: 0.75
        case .administration, .sport: 0.5
        case .other: 0.4
        }
    }

    var isHighValue: Bool { self == .selfDevelopment || self == .work || self == .education }
}

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low, medium, high, critical

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

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
        case .forgot: "I forgot"
        case .procrastinated: "I procrastinated"
        case .lazy: "I was lazy"
        case .didNotFeelLikeIt: "I didn't feel like it"
        case .plannedBadly: "I planned badly"
        case .noTime: "I didn't have enough time"
        case .unexpected: "Unexpected situation"
        case .health: "Health"
        case .other: "Other"
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
        case .removed: "Removed"
        case .moved: "Moved"
        case .priorityLowered: "Priority lowered"
        case .priorityRaised: "Priority raised"
        case .deadlineChanged: "Deadline changed"
        case .weightLowered: "Weight lowered"
        case .weightRaised: "Weight raised"
        case .addedLater: "Added after commitment"
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
