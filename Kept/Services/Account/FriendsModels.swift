import Foundation

/// Someone found by an identifier or a code. Before a request is accepted, only the name and the initial are known.
struct FoundPerson: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var initial: String
}

struct Friend: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var handle: String
    var since: Date?
    /// "Do not disturb" is on. The reason is filled in only when the friend chose to show it.
    var dnd: Bool = false
    var dndReasonKey: String?
    var dndReasonText: String?
}

/// A poke someone sent to the user: their own short text and nothing else.
struct ReceivedPoke: Codable, Equatable, Identifiable {
    var id: UUID
    var senderId: UUID
    var senderName: String
    var body: String
    var createdAt: Date
    var seen: Bool
}

struct PokeCooldown: Codable, Equatable {
    var recipient: UUID
    var availableAt: Date
}

/// Why someone does not want to be disturbed. The list is short on purpose; anything else is a custom reason of a few words.
enum DNDReason: String, CaseIterable, Identifiable {
    case work, school, training, trip, vacation, sleep, illness, calm, family, focus, custom
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .work: "Práce"
        case .school: "Škola"
        case .training: "Trénink"
        case .trip: "Cesta"
        case .vacation: "Dovolená"
        case .sleep: "Spánek"
        case .illness: "Nemoc"
        case .calm: "Klid"
        case .family: "Rodina"
        case .focus: "Soustředění"
        case .custom: "Vlastní důvod"
        }
    }

    static let maxWords = 6
    static let maxCharacters = 60

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    static func isValidCustom(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxCharacters && wordCount(trimmed) <= maxWords
    }
}

enum PokeText {
    static let maxCharacters = 100

    /// Links are not allowed. This only catches the plain cases; the server checks again.
    static func containsLink(_ text: String) -> Bool {
        text.range(of: #"(https?://|www\.|\b[a-z0-9-]+\.(com|cz|sk|net|org|io|me|ly|app|eu|gg)\b)"#,
                   options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isSendable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maxCharacters && !containsLink(trimmed)
    }
}

struct FriendRequest: Codable, Equatable, Identifiable {
    enum Direction: String, Codable { case incoming, outgoing }
    var id: UUID
    var displayName: String
    var initial: String
    var direction: Direction
    var createdAt: Date
}

struct BlockedPerson: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
}

enum ReportReason: String, CaseIterable, Identifiable {
    case abuse, threat, sexual, spam, impersonation, other
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .abuse: "Urážky nebo šikana"
        case .threat: "Výhrůžky"
        case .sexual: "Nevhodný sexuální obsah"
        case .spam: "Spam nebo reklama"
        case .impersonation: "Vydává se za někoho jiného"
        case .other: "Něco jiného"
        }
    }
}

/// The two ways a person is added: the whole identifier ("Jana#4827") or the code from a QR code.
enum FriendLink {
    static let scheme = "kept"

    /// What the personal QR code holds.
    static func url(code: String) -> URL? { URL(string: "\(scheme)://friend/\(code)") }

    /// The code in a scanned or opened link, if it is one of ours.
    static func code(from url: URL) -> String? {
        guard url.scheme == scheme, url.host() == "friend" else { return nil }
        let code = url.lastPathComponent
        return code.range(of: #"^[0-9a-f]{12}$"#, options: .regularExpression) != nil ? code : nil
    }

    /// Whether the text is a whole identifier ("Jana#4827"). Typing is the only way besides the QR code, and a bare name finds nobody.
    static func isSearchable(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).range(of: #"^.{1,24}#[0-9]{4}$"#, options: .regularExpression) != nil
    }
}

extension ServerClient {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "date"))
        }
        return decoder
    }()

    private func rpc(_ name: String, _ body: [String: Any] = [:], token: String) async throws -> Data {
        try await request("rest/v1/rpc/\(name)", method: "POST", body: body, token: token)
    }

    func find(_ query: String, token: String) async throws -> FoundPerson? {
        let data = try await rpc("find_profile", ["p_query": query], token: token)
        return try Self.decoder.decode([FoundPerson].self, from: data).first
    }

    /// "requested" or, when the other person had asked first, "accepted".
    func sendRequest(to id: UUID, token: String) async throws -> String {
        let data = try await rpc("send_friend_request", ["p_target": id.uuidString], token: token)
        return try Self.decoder.decode(String.self, from: data)
    }

    func respond(to id: UUID, accept: Bool, token: String) async throws {
        _ = try await rpc("respond_friend_request", ["p_from": id.uuidString, "p_accept": accept], token: token)
    }

    func remove(_ id: UUID, token: String) async throws {
        _ = try await rpc("remove_friend", ["p_user": id.uuidString], token: token)
    }

    func block(_ id: UUID, token: String) async throws {
        _ = try await rpc("block_user", ["p_user": id.uuidString], token: token)
    }

    func unblock(_ id: UUID, token: String) async throws {
        _ = try await rpc("unblock_user", ["p_user": id.uuidString], token: token)
    }

    func report(_ id: UUID, reason: ReportReason, note: String, token: String) async throws {
        _ = try await rpc("report_user", ["p_user": id.uuidString, "p_reason": reason.rawValue, "p_note": note], token: token)
    }

    func rotateInviteCode(token: String) async throws -> String {
        let data = try await rpc("rotate_invite_code", token: token)
        return try Self.decoder.decode(String.self, from: data)
    }

    func sendPoke(to id: UUID, text: String, token: String) async throws {
        _ = try await rpc("send_poke", ["p_to": id.uuidString, "p_body": text], token: token)
    }

    func pokes(token: String) async throws -> [ReceivedPoke] {
        try Self.decoder.decode([ReceivedPoke].self, from: try await rpc("pokes_inbox", token: token))
    }

    func cooldowns(token: String) async throws -> [PokeCooldown] {
        try Self.decoder.decode([PokeCooldown].self, from: try await rpc("poke_cooldowns", token: token))
    }

    func markPokesSeen(token: String) async throws {
        _ = try await rpc("mark_pokes_seen", token: token)
    }

    func deletePoke(_ id: UUID, token: String) async throws {
        _ = try await rpc("delete_poke", ["p_id": id.uuidString], token: token)
    }

    func reportPoke(_ id: UUID, reason: ReportReason, token: String) async throws {
        _ = try await rpc("report_poke", ["p_id": id.uuidString, "p_reason": reason.rawValue], token: token)
    }

    /// `hours` 0 keeps it on until it is turned off.
    func setDND(active: Bool, reason: DNDReason?, text: String, shared: Bool, hours: Int, token: String) async throws {
        var body: [String: Any] = ["p_active": active, "p_share": shared, "p_hours": hours]
        body["p_reason_key"] = reason?.rawValue ?? NSNull()
        body["p_reason_text"] = reason == .custom ? text : NSNull()
        _ = try await rpc("set_dnd", body, token: token)
    }

    func friends(token: String) async throws -> [Friend] {
        try Self.decoder.decode([Friend].self, from: try await rpc("my_friends", token: token))
    }

    func requests(token: String) async throws -> [FriendRequest] {
        try Self.decoder.decode([FriendRequest].self, from: try await rpc("my_requests", token: token))
    }

    func blocks(token: String) async throws -> [BlockedPerson] {
        try Self.decoder.decode([BlockedPerson].self, from: try await rpc("my_blocks", token: token))
    }
}
