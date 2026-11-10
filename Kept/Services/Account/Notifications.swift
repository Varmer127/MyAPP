import Foundation
import Observation
import UserNotifications

/// Something a friend did that the user should hear about.
struct AppNotification: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case friendRequest = "friend_request", friendAccepted = "friend_accepted", poke, reaction
        case betInvite = "bet_invite", betClaim = "bet_claim", betResult = "bet_result"
        case challengeInvite = "challenge_invite", groupInvite = "group_invite", activityInvite = "activity_invite"
        case buddyRequest = "buddy_request", buddyAccepted = "buddy_accepted"
        case witnessRequest = "witness_request", witnessAnswer = "witness_answer"
    }

    var id: UUID
    var kind: Kind
    var actorId: UUID?
    var actorName: String?
    var ref: UUID?
    var body: String?
    var createdAt: Date
    var seen: Bool

    private var who: String { actorName ?? String(localized: "Přítel") }

    /// One line for the bell and for a notification on the lock screen.
    var title: String {
        switch kind {
        case .friendRequest: String(localized: "\(who) tě chce mezi přátele")
        case .friendAccepted: String(localized: "\(who) a ty jste teď přátelé")
        case .poke: String(localized: "\(who) ti posílá šťouchnutí")
        case .reaction: String(localized: "\(who) ti fandí")
        case .betInvite: String(localized: "\(who) tě zve do sázky")
        case .betClaim: String(localized: "\(who) hlásí splněnou sázku")
        case .betResult: String(localized: "Sázka je vyhodnocená")
        case .challengeInvite: String(localized: "\(who) tě zve do výzvy")
        case .groupInvite: String(localized: "\(who) tě zve do skupiny")
        case .activityInvite: String(localized: "\(who) tě zve na společnou aktivitu")
        case .buddyRequest: String(localized: "\(who) ti nabízí parťáctví")
        case .buddyAccepted: String(localized: "\(who) a ty jste teď parťáci")
        case .witnessRequest: String(localized: "\(who) tě prosí o potvrzení")
        case .witnessAnswer: String(localized: "\(who) má pro tebe verdikt")
        }
    }

    /// The second line: the poke's text, the bet's or challenge's name, or the witness's answer.
    var detail: String? {
        guard let body, !body.isEmpty else { return nil }
        switch kind {
        case .reaction: return ReactionKind(rawValue: body).map { String(localized: $0.title) }
        case .witnessAnswer:
            let parts = body.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return body }
            return parts[0] == "confirmed" ? String(localized: "Potvrzeno: \(parts[1])") : String(localized: "Nepotvrzeno: \(parts[1])")
        default: return body
        }
    }

    /// Kinds that only tell something; the ones that ask for an answer have their own place in the inbox.
    var isNews: Bool { [.friendAccepted, .reaction, .betResult, .buddyAccepted, .witnessAnswer].contains(kind) }
}

struct PokeMute: Codable, Equatable {
    var muted: UUID
    /// Nil means for good.
    var until: Date?
}

extension ServerClient {
    func notifications(since: Date?, token: String) async throws -> [AppNotification] {
        let since: Any = since.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
        return try Self.socialDecoder.decode([AppNotification].self, from: try await rpc("my_notifications", ["p_since": since], token: token))
    }

    /// `days` 0 mutes for good, nil removes the mute.
    func mutePokes(from id: UUID, days: Int?, token: String) async throws {
        _ = try await rpc("mute_pokes", ["p_from": id.uuidString, "p_days": days.map { $0 as Any } ?? NSNull()], token: token)
    }

    func setPokesMuted(_ muted: Bool, token: String) async throws {
        _ = try await rpc("set_pokes_muted", ["p_muted": muted], token: token)
    }

    func pokeMutes(token: String) async throws -> [PokeMute] {
        try Self.socialDecoder.decode([PokeMute].self, from: try await rpc("my_poke_mutes", token: token))
    }

    func markNotificationsSeen(token: String) async throws {
        _ = try await rpc("mark_notifications_seen", token: token)
    }
}

/// Keeps the notifications fresh while the app is open, shows a poke that arrives right away, and posts
/// local notifications when iOS lets the app check in the background. Real push comes with the Apple Developer account.
@MainActor @Observable
final class NotificationsService {
    static let shared = NotificationsService()

    private(set) var items: [AppNotification] = []
    /// A poke that arrived while the app is on screen, for the animation.
    var incomingPoke: AppNotification?

    private let client = ServerClient()
    private let account = AccountService.shared
    private static let lastAnnouncedKey = "lastAnnouncedNotification"
    static let refreshTaskID = "cz.philipstryka.kept.refresh"

    var news: [AppNotification] { items.filter(\.isNews) }
    var unseenNews: Int { news.filter { !$0.seen }.count }

    /// Loads the list. A poke that arrives while the app is on screen gets the animation; everything else
    /// that is new since the last announcement (a friend request, an invitation, an accepted request…)
    /// comes as a notification banner, so it is not missed while the user looks elsewhere.
    func reload() async {
        guard account.profile != nil,
              let loaded = try? await account.perform({ try await client.notifications(since: nil, token: $0) }) else { return }
        let known = Set(items.map(\.id))
        let poke = items.isEmpty ? nil : loaded.first { $0.kind == .poke && !$0.seen && !known.contains($0.id) }
        if let poke { incomingPoke = poke }
        let lastAnnounced = UserDefaults.standard.object(forKey: Self.lastAnnouncedKey) as? Date ?? .distantPast
        await post(loaded.filter { !$0.seen && $0.createdAt > lastAnnounced && $0.id != poke?.id })
        items = loaded
        markAnnounced(loaded.first?.createdAt)
    }

    /// Local notifications for the items, oldest first; tapping one opens the bell.
    private func post(_ fresh: [AppNotification]) async {
        for item in fresh.sorted(by: { $0.createdAt < $1.createdAt }) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            if let detail = item.detail { content.body = detail }
            content.sound = .default
            content.threadIdentifier = "social"
            content.userInfo = [NotificationRouter.routeKey: AppRoute.inbox.rawValue]
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "social.\(item.id)", content: content, trigger: nil))
        }
    }

    private(set) var mutes: [UUID: PokeMute] = [:]

    func loadMutes() async {
        guard let loaded = try? await account.perform({ try await client.pokeMutes(token: $0) }) else { return }
        mutes = Dictionary(uniqueKeysWithValues: loaded.map { ($0.muted, $0) })
    }

    /// `days` 0 mutes for good, nil removes the mute.
    func mutePokes(from id: UUID, days: Int?) async throws {
        try await account.perform { try await client.mutePokes(from: id, days: days, token: $0) }
        await loadMutes()
    }

    func setAllPokesMuted(_ muted: Bool) async throws {
        try await account.perform { try await client.setPokesMuted(muted, token: $0) }
        await account.reload()
    }

    func markSeen() async {
        guard items.contains(where: { !$0.seen }) else { return }
        _ = try? await account.perform { try await client.markNotificationsSeen(token: $0) }
        items = items.map { var item = $0; item.seen = true; return item }
    }

    /// Background check: everything new since the last announcement becomes a local notification.
    func announceNewInBackground() async {
        await account.restore()
        guard account.profile != nil else { return }
        let since = UserDefaults.standard.object(forKey: Self.lastAnnouncedKey) as? Date ?? .now.addingTimeInterval(-3600)
        guard let fresh = try? await account.perform({ try await client.notifications(since: since, token: $0) }) else { return }
        await post(fresh.filter { !$0.seen && $0.createdAt > since })
        markAnnounced(fresh.first?.createdAt)
    }

    private func markAnnounced(_ date: Date?) {
        guard let date else { return }
        let previous = UserDefaults.standard.object(forKey: Self.lastAnnouncedKey) as? Date ?? .distantPast
        if date > previous { UserDefaults.standard.set(date, forKey: Self.lastAnnouncedKey) }
    }
}
