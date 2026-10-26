import Foundation
import Observation

/// Friends, open requests and blocked people, as the server holds them.
@MainActor @Observable
final class FriendsService {
    static let shared = FriendsService()

    private(set) var friends: [Friend] = []
    private(set) var requests: [FriendRequest] = []
    private(set) var blocked: [BlockedPerson] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false

    private let client = ServerClient()
    private let account = AccountService.shared

    var incoming: [FriendRequest] { requests.filter { $0.direction == .incoming } }
    var outgoing: [FriendRequest] { requests.filter { $0.direction == .outgoing } }

    func reload() async {
        guard account.isSignedIn else {
            friends = []; requests = []; blocked = []; hasLoaded = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await account.perform { token in
                async let friends = client.friends(token: token)
                async let requests = client.requests(token: token)
                async let blocked = client.blocks(token: token)
                return try await (friends, requests, blocked)
            }
            friends = result.0
            requests = result.1
            blocked = result.2
            hasLoaded = true
        } catch {
            // The last known lists stay on screen when the network is away.
        }
    }

    func find(_ query: String) async throws -> FoundPerson? {
        try await account.perform { try await client.find(query.trimmingCharacters(in: .whitespaces).lowercased(), token: $0) }
    }

    /// Returns true when the other person had asked first, so the two are friends right away.
    @discardableResult
    func request(_ person: FoundPerson) async throws -> Bool {
        let outcome = try await account.perform { try await client.sendRequest(to: person.id, token: $0) }
        await reload()
        return outcome == "accepted"
    }

    func respond(to request: FriendRequest, accept: Bool) async throws {
        try await account.perform { try await client.respond(to: request.id, accept: accept, token: $0) }
        await reload()
    }

    func cancel(_ request: FriendRequest) async throws {
        try await account.perform { try await client.remove(request.id, token: $0) }
        await reload()
    }

    func remove(_ id: UUID) async throws {
        try await account.perform { try await client.remove(id, token: $0) }
        await reload()
    }

    func block(_ id: UUID) async throws {
        try await account.perform { try await client.block(id, token: $0) }
        await reload()
    }

    func unblock(_ id: UUID) async throws {
        try await account.perform { try await client.unblock(id, token: $0) }
        await reload()
    }

    func report(_ id: UUID, reason: ReportReason, note: String) async throws {
        try await account.perform { try await client.report(id, reason: reason, note: note, token: $0) }
    }

    func rotateInviteCode() async throws {
        _ = try await account.perform { try await client.rotateInviteCode(token: $0) }
        await account.reload()
    }
}
