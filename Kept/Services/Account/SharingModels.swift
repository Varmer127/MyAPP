import Foundation
import SwiftData

/// How much of the week friends see. Nothing is the default.
enum ShareLevel: String, CaseIterable, Identifiable, Codable {
    case none, summary, plan
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .none: "Nic"
        case .summary: "Souhrn týdne"
        case .plan: "Celý plán týdne"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .none: "Přátelé uvidí jen tvoje jméno."
        case .summary: "Spolehlivost, kolik slibů máš splněno a sérii. Bez názvů úkolů."
        case .plan: "Navíc názvy úkolů, dny a jestli jsou splněné. Poznámky, důvody a sázky nikdy."
        }
    }
}

enum ReactionKind: String, CaseIterable, Identifiable, Codable {
    case fire, clap, strong, heart
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fire: "flame.fill"
        case .clap: "hands.clap.fill"
        case .strong: "figure.strengthtraining.traditional"
        case .heart: "heart.fill"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .fire: "Hoříš"
        case .clap: "Potlesk"
        case .strong: "Síla"
        case .heart: "Fandím ti"
        }
    }
}

struct SharedTask: Codable, Equatable, Identifiable {
    var day: Date
    var title: String
    var category: String
    var status: String
    var id: String { "\(day.timeIntervalSince1970)-\(title)-\(status)" }
    var isDone: Bool { status == "done" }
    var isMissed: Bool { status == "missed" }
}

/// A friend's week, as far as they share it.
struct FriendWeek: Codable, Equatable {
    var level: ShareLevel
    var myReactions: [ReactionKind]
    var reliability: Int?
    var done: Int?
    var total: Int?
    var streak: Int?
    var sealed: Bool?
    var tasks: [SharedTask]?
}

struct LeaderboardRow: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var isMe: Bool
    var reliability: Int?
    var badges: Int
    var streak: Int
}

struct ReceivedReaction: Codable, Equatable, Identifiable {
    var senderId: UUID
    var senderName: String
    var kind: ReactionKind
    var weekStart: Date
    var createdAt: Date
    var seen: Bool
    var id: String { "\(senderId)-\(kind.rawValue)-\(weekStart.timeIntervalSince1970)" }
}

/// The numbers of one week as the app sends them. Computed here so it can be tested without a server.
struct WeekSnapshot: Equatable {
    var weekStart: Date
    var reliability: Int?
    var done: Int
    var total: Int
    var streak: Int
    var badges: Int
    var sealed: Bool
    var tasks: [SharedTask]

    /// Reliability is the share of kept promises; before anything was promised, the productivity of what is already closed.
    static func make(week: Date, tasks: [TaskItem], plans: [WeeklyPlan], streak: Int, badges: Int,
                     includePlan: Bool, now: Date = .now) -> WeekSnapshot {
        let inWeek = tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate.weekStart == week }
        let closed = inWeek.filter { $0.isClosed(now) }
        let share = ScoreEngine.promisesKept(inWeek, now: now) ?? ScoreEngine.productivity(closed, now: now)
        let shared: [SharedTask] = includePlan
            ? inWeek.sorted { $0.dueDate < $1.dueDate }.prefix(60).map { task in
                SharedTask(day: task.scheduledDate.startOfDay, title: String(task.title.prefix(80)),
                           category: task.category.rawValue,
                           status: task.isDone ? "done" : (task.isClosed(now) ? "missed" : "open"))
            }
            : []
        return WeekSnapshot(weekStart: week, reliability: share.map { Int(($0 * 100).rounded()) },
                            done: inWeek.filter(\.isDone).count, total: inWeek.count, streak: streak, badges: badges,
                            sealed: plans.first { $0.weekStart == week }?.isCommitted == true, tasks: shared)
    }
}

enum DayString {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ text: String) -> Date? { formatter.date(from: text) }
}
