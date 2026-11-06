import Foundation
import Observation

/// A bet for points between friends. Points never mean money; stakes are held until the bet ends.
struct Bet: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case week, goal }
    enum Status: String, Codable { case open, settled, refunded, cancelled }

    struct Participant: Codable, Equatable, Identifiable {
        enum State: String, Codable { case invited, accepted, declined }
        var id: UUID
        var name: String
        var status: State
        var respondedAt: Date?
        var verdict: String?
        var isMe: Bool
    }

    var id: UUID
    var kind: Kind
    var title: String
    var terms: String?
    var stake: Int
    var endsAt: Date
    var status: Status
    var winner: UUID?
    var claimant: UUID?
    var settledAt: Date?
    var createdAt: Date
    var isCreator: Bool
    var participants: [Participant]

    var me: Participant? { participants.first(where: \.isMe) }
    var accepted: [Participant] { participants.filter { $0.status == .accepted } }
    /// Everything the winner takes.
    var pot: Int { stake * accepted.count }
    var isOpen: Bool { status == .open }
    var awaitsMyAnswer: Bool { isOpen && me?.status == .invited }
    /// Someone claimed the goal and the user still has to confirm or dispute it.
    var awaitsMyVerdict: Bool {
        guard isOpen, let claimant, let me, me.status == .accepted, me.id != claimant else { return false }
        return me.verdict == nil
    }

    func name(of id: UUID?) -> String? { participants.first { $0.id == id }?.name }
}

/// How bets change the user's points, kept on the phone so a finished bet keeps counting after the server forgets it.
enum BetLedger {
    struct Event: Codable, Equatable {
        var date: Date
        var change: Int
    }

    private static let key = "betLedger"

    /// What one bet did to the user's points: the stake leaves when joining; the pot comes back on a win,
    /// the stake comes back when the bet is refunded or called off.
    static func events(for bet: Bet) -> [Event] {
        guard let me = bet.me, me.status == .accepted else { return [] }
        var events = [Event(date: me.respondedAt ?? bet.createdAt, change: -bet.stake)]
        let closedAt = bet.settledAt ?? bet.endsAt
        switch bet.status {
        case .settled where bet.winner == me.id: events.append(Event(date: closedAt, change: bet.pot))
        case .refunded, .cancelled: events.append(Event(date: closedAt, change: bet.stake))
        default: break
        }
        return events
    }

    static func store(_ bets: [Bet], in defaults: UserDefaults = .standard) {
        var all = load(defaults)
        for bet in bets { all[bet.id.uuidString] = events(for: bet) }
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }

    static func load(_ defaults: UserDefaults = .standard) -> [String: [Event]] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: [Event]].self, from: data)) ?? [:]
    }

    /// Point changes from all bets, for the balance.
    static func allEvents(_ defaults: UserDefaults = .standard) -> [(date: Date, change: Int)] {
        load(defaults).values.flatMap { $0 }.map { ($0.date, $0.change) }
    }
}

extension ServerClient {
    func bets(token: String) async throws -> [Bet] {
        try Self.socialDecoder.decode([Bet].self, from: try await rpc("my_bets", token: token))
    }

    func createBet(kind: Bet.Kind, title: String, terms: String, stake: Int, days: Int, invitees: [UUID], token: String) async throws {
        _ = try await rpc("create_bet", ["p_kind": kind.rawValue, "p_title": title, "p_terms": terms, "p_stake": stake,
                                         "p_days": days, "p_invitees": invitees.map(\.uuidString)], token: token)
    }

    func respondBet(_ id: UUID, accept: Bool, token: String) async throws {
        _ = try await rpc("respond_bet", ["p_bet": id.uuidString, "p_accept": accept], token: token)
    }

    func inviteToBet(_ id: UUID, invitees: [UUID], token: String) async throws {
        _ = try await rpc("invite_to_bet", ["p_bet": id.uuidString, "p_invitees": invitees.map(\.uuidString)], token: token)
    }

    func claimBet(_ id: UUID, token: String) async throws {
        _ = try await rpc("claim_bet", ["p_bet": id.uuidString], token: token)
    }

    func judgeBet(_ id: UUID, confirm: Bool, token: String) async throws {
        _ = try await rpc("judge_bet", ["p_bet": id.uuidString, "p_confirm": confirm], token: token)
    }

    func cancelBet(_ id: UUID, token: String) async throws {
        _ = try await rpc("cancel_bet", ["p_bet": id.uuidString], token: token)
    }
}

@MainActor @Observable
final class BetsService {
    static let shared = BetsService()

    private(set) var bets: [Bet] = []
    private let client = ServerClient()
    private let account = AccountService.shared

    var open: [Bet] { bets.filter(\.isOpen) }
    var finished: [Bet] { bets.filter { !$0.isOpen } }
    /// Invitations and claims waiting for the user.
    var waiting: [Bet] { bets.filter { $0.awaitsMyAnswer || $0.awaitsMyVerdict } }

    func reload() async {
        guard account.isSignedIn else { bets = []; return }
        guard let loaded = try? await account.perform({ try await client.bets(token: $0) }) else { return }
        bets = loaded
        BetLedger.store(loaded)
    }

    func create(kind: Bet.Kind, title: String, terms: String, stake: Int, days: Int, invitees: [UUID]) async throws {
        try await account.perform {
            try await client.createBet(kind: kind, title: title, terms: terms, stake: stake, days: days, invitees: invitees, token: $0)
        }
        await reload()
    }

    func respond(_ bet: Bet, accept: Bool) async throws {
        try await account.perform { try await client.respondBet(bet.id, accept: accept, token: $0) }
        await reload()
    }

    func invite(_ friends: [UUID], to bet: Bet) async throws {
        try await account.perform { try await client.inviteToBet(bet.id, invitees: friends, token: $0) }
        await reload()
    }

    func claim(_ bet: Bet) async throws {
        try await account.perform { try await client.claimBet(bet.id, token: $0) }
        await reload()
    }

    func judge(_ bet: Bet, confirm: Bool) async throws {
        try await account.perform { try await client.judgeBet(bet.id, confirm: confirm, token: $0) }
        await reload()
    }

    func cancel(_ bet: Bet) async throws {
        try await account.perform { try await client.cancelBet(bet.id, token: $0) }
        await reload()
    }
}
