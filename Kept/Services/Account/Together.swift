import Foundation
import Observation
import SwiftData

// Witness, pair buddy, shared challenges, groups and shared activities: the "together" part of friends.

struct WitnessTask: Codable, Equatable, Identifiable {
    var id: UUID
    var ownerName: String
    var title: String
    var day: Date
}

struct WitnessResult: Codable, Equatable {
    var taskRef: UUID
    var witnessName: String
    var status: String
}

struct Witnessing: Codable, Equatable {
    var toAnswer: [WitnessTask]
    var mine: [WitnessResult]
}

struct Buddy: Codable, Equatable, Identifiable {
    enum State: String, Codable { case paired, outgoing, incoming }
    var id: UUID
    var name: String
    var state: State
    var day: Date?
    var done: Int?
    var total: Int?
}

struct Member: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var status: String
    var isMe: Bool
    var progress: Int?
    var reliability: Int?
    var isAccepted: Bool { status == "accepted" }
}

struct Challenge: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var category: String?
    var target: Int
    var startsOn: Date
    var endsOn: Date
    var isCreator: Bool
    var myStatus: String
    var members: [Member]
    var isInvited: Bool { myStatus == "invited" }
}

struct FriendGroup: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var isOwner: Bool
    var myStatus: String
    var members: [Member]
    var isInvited: Bool { myStatus == "invited" }
}

struct SharedActivity: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var category: String
    var startsAt: Date
    var minutes: Int
    var isCreator: Bool
    var myStatus: String
    var members: [Member]
    var isInvited: Bool { myStatus == "invited" }
}

extension ServerClient {
    private func call<T: Decodable>(_ name: String, _ body: [String: Any] = [:], as type: T.Type, token: String) async throws -> T {
        try Self.socialDecoder.decode(T.self, from: try await rpc(name, body, token: token))
    }

    func witnessing(token: String) async throws -> Witnessing { try await call("my_witnessing", as: Witnessing.self, token: token) }
    func buddies(token: String) async throws -> [Buddy] { try await call("my_buddy", as: [Buddy].self, token: token) }
    func challenges(token: String) async throws -> [Challenge] { try await call("my_challenges", as: [Challenge].self, token: token) }
    func groups(token: String) async throws -> [FriendGroup] { try await call("my_groups", as: [FriendGroup].self, token: token) }
    func activities(token: String) async throws -> [SharedActivity] { try await call("my_activities", as: [SharedActivity].self, token: token) }
}

@MainActor @Observable
final class TogetherService {
    static let shared = TogetherService()

    private(set) var witnessing = Witnessing(toAnswer: [], mine: [])
    private(set) var buddies: [Buddy] = []
    private(set) var challenges: [Challenge] = []
    private(set) var groups: [FriendGroup] = []
    private(set) var activities: [SharedActivity] = []

    private let client = ServerClient()
    private let account = AccountService.shared

    var buddy: Buddy? { buddies.first { $0.state == .paired } }
    var incomingBuddy: Buddy? { buddies.first { $0.state == .incoming } }
    /// Everything that waits for an answer from the user.
    var waitingCount: Int {
        witnessing.toAnswer.count + (incomingBuddy == nil ? 0 : 1) + challenges.filter(\.isInvited).count
            + groups.filter(\.isInvited).count + activities.filter(\.isInvited).count
    }

    func reload() async {
        guard account.isSignedIn else {
            witnessing = Witnessing(toAnswer: [], mine: []); buddies = []; challenges = []; groups = []; activities = []
            return
        }
        guard let all = try? await account.perform({ token in
            async let w = client.witnessing(token: token)
            async let b = client.buddies(token: token)
            async let c = client.challenges(token: token)
            async let g = client.groups(token: token)
            async let a = client.activities(token: token)
            return try await (w, b, c, g, a)
        }) else { return }
        witnessing = all.0; buddies = all.1; challenges = all.2; groups = all.3; activities = all.4
    }

    /// Calls a server function that changes something, then loads everything again.
    func run(_ name: String, _ body: [String: Any]) async throws {
        _ = try await account.perform { try await client.rpc(name, body, token: $0) }
        await reload()
    }

    // MARK: Witness

    func requestWitness(_ friend: Friend, for task: TaskItem) async throws {
        try await run("request_witness", ["p_witness": friend.id.uuidString, "p_task": task.uid.uuidString,
                                          "p_title": String(task.title.prefix(80)), "p_day": DayString.string(task.scheduledDate)])
    }

    func witnessResult(for task: TaskItem) -> WitnessResult? { witnessing.mine.first { $0.taskRef == task.uid } }

    func answer(_ request: WitnessTask, confirm: Bool) async throws {
        try await run("answer_witness", ["p_id": request.id.uuidString, "p_confirm": confirm])
    }

    // MARK: Buddy

    func askBuddy(_ friend: Friend) async throws { try await run("request_buddy", ["p_friend": friend.id.uuidString]) }
    func respondBuddy(_ buddy: Buddy, accept: Bool) async throws {
        try await run("respond_buddy", ["p_from": buddy.id.uuidString, "p_accept": accept])
    }
    func endBuddy() async throws { try await run("end_buddy", [:]) }

    // MARK: Challenges, groups, activities

    func createChallenge(title: String, category: TaskCategory?, target: Int, days: Int, invitees: [UUID]) async throws {
        try await run("create_challenge", ["p_title": title, "p_category": category?.rawValue ?? "", "p_target": target,
                                           "p_days": days, "p_invitees": invitees.map(\.uuidString)])
    }
    func respond(_ challenge: Challenge, accept: Bool) async throws {
        try await run("respond_challenge", ["p_id": challenge.id.uuidString, "p_accept": accept])
    }
    func leave(_ challenge: Challenge) async throws { try await run("leave_challenge", ["p_id": challenge.id.uuidString]) }

    func createGroup(name: String, invitees: [UUID]) async throws {
        try await run("create_group", ["p_name": name, "p_invitees": invitees.map(\.uuidString)])
    }
    func invite(_ friends: [UUID], to group: FriendGroup) async throws {
        try await run("invite_to_group", ["p_group": group.id.uuidString, "p_invitees": friends.map(\.uuidString)])
    }
    func respond(_ group: FriendGroup, accept: Bool) async throws {
        try await run("respond_group", ["p_group": group.id.uuidString, "p_accept": accept])
    }
    func leave(_ group: FriendGroup) async throws { try await run("leave_group", ["p_group": group.id.uuidString]) }

    func createActivity(title: String, category: TaskCategory, startsAt: Date, minutes: Int, invitees: [UUID], context: ModelContext) async throws {
        let id: UUID = try await account.perform { token in
            let data = try await client.rpc("create_activity", [
                "p_title": title, "p_category": category.rawValue, "p_starts_at": ISO8601DateFormatter().string(from: startsAt),
                "p_minutes": minutes, "p_invitees": invitees.map(\.uuidString)], token: token)
            return try ServerClient.socialDecoder.decode(UUID.self, from: data)
        }
        ActivityPlanner.addToPlan(SharedActivity(id: id, title: title, category: category.rawValue, startsAt: startsAt,
                                                 minutes: minutes, isCreator: true, myStatus: "accepted", members: []), in: context)
        await reload()
    }

    func respond(_ activity: SharedActivity, accept: Bool, context: ModelContext) async throws {
        try await run("respond_activity", ["p_id": activity.id.uuidString, "p_accept": accept])
        if accept { ActivityPlanner.addToPlan(activity, in: context) }
    }

    // MARK: Sync

    /// Today's numbers for the buddy and each accepted challenge's progress, computed from the phone's tasks.
    func push(tasks: [TaskItem], now: Date = .now) async {
        if buddy != nil {
            let today = tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate.isSameDay(as: now) }
            _ = try? await account.perform { try await client.rpc("push_day", ["p_day": DayString.string(now),
                "p_done": today.filter(\.isDone).count, "p_total": today.count], token: $0) }
        }
        for challenge in challenges where !challenge.isInvited && challenge.endsOn >= now.startOfDay.addingDays(-1) {
            let progress = ChallengeProgress.count(tasks: tasks, challenge: challenge)
            guard progress != challenge.members.first(where: \.isMe)?.progress else { continue }
            _ = try? await account.perform { try await client.rpc("push_challenge_progress",
                ["p_id": challenge.id.uuidString, "p_progress": progress], token: $0) }
        }
    }
}

enum ChallengeProgress {
    /// Finished tasks of the challenge's kind (or any kind) within its days.
    static func count(tasks: [TaskItem], challenge: Challenge) -> Int {
        let last = challenge.endsOn.addingDays(1)
        return tasks.filter {
            $0.isDone && $0.scheduledDate >= challenge.startsOn && $0.scheduledDate < last
                && (challenge.category == nil || $0.category.rawValue == challenge.category)
        }.count
    }
}

/// An accepted shared activity becomes a task in the user's own plan, once.
enum ActivityPlanner {
    private static let key = "activityTasks"

    static func addToPlan(_ activity: SharedActivity, in context: ModelContext, defaults: UserDefaults = .standard) {
        var added = defaults.stringArray(forKey: key) ?? []
        guard !added.contains(activity.id.uuidString), activity.startsAt > .now else { return }
        var draft = TaskDraft(date: activity.startsAt)
        draft.title = activity.title
        draft.category = TaskCategory(rawValue: activity.category) ?? .other
        draft.plannedMinutes = activity.minutes
        draft.hasDeadline = true
        draft.deadlineTime = activity.startsAt.addingTimeInterval(TimeInterval(activity.minutes * 60))
        draft.weight = UserSettings.current(in: context).defaultWeight(category: draft.category, priority: draft.priority)
        _ = PlanService.save(draft, to: nil, in: context)
        Persistence.save(context)
        added.append(activity.id.uuidString)
        defaults.set(added, forKey: key)
    }
}
