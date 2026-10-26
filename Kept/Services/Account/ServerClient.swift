import Foundation

/// A sign-in session as the server hands it out.
struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: UUID

    var needsRefresh: Bool { expiresAt.timeIntervalSinceNow < 60 }
}

/// The part of the profile the app needs. Everything else stays on the server.
struct AccountProfile: Codable, Equatable {
    var id: UUID
    var displayName: String
    var handleNumber: Int
    var nameChangedAt: Date?
    /// The secret in the personal QR code and link. Only the owner ever receives it.
    var inviteCode: String?

    /// How friends write it down, for example "Jana#4827".
    var handle: String { "\(displayName)#\(handleNumber)" }
}

/// Why a call to the server failed. `code` is the short word the database raises (for example "too_young").
struct ServerError: Error, Equatable {
    var status: Int
    var code: String

    var isUnauthorized: Bool { status == 401 || code == "not_signed_in" || code == "invalid_grant" }
}

/// A light check before an address is sent to the server: one "@", something on both sides, a dot in the domain.
enum EmailAddress {
    static func isPlausible(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespaces)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, value.count <= 254, !value.contains(" ") else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }
}

/// A small client for the three things the app needs: sign-in tokens, database functions and one table.
/// Written by hand on URLSession to keep the app free of a large third-party package.
struct ServerClient {
    var session: URLSession = .shared

    func request(_ path: String, method: String = "GET", query: [URLQueryItem] = [],
                         body: [String: Any]? = nil, token: String? = nil) async throws -> Data {
        var components = URLComponents(url: ServerConfig.url.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(ServerConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token ?? ServerConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw Self.error(status: status, data: data) }
        return data
    }

    /// The server answers with {"message": "too_young"}, {"error_code": "..."} or {"error": "..."}; only a short word is kept.
    static func error(status: Int, data: Data) -> ServerError {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let raw = (object?["message"] as? String) ?? (object?["error_code"] as? String)
            ?? (object?["error"] as? String) ?? (object?["msg"] as? String) ?? ""
        let code = raw.range(of: #"^[a-z_]{3,40}$"#, options: .regularExpression) != nil ? raw : "unknown"
        return ServerError(status: status, code: code)
    }

    // MARK: Sign-in

    /// The page where the person signs in with the chosen provider.
    func authorizeURL(provider: String, challenge: String) -> URL {
        var components = URLComponents(url: ServerConfig.url.appending(path: "auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: ServerConfig.redirectURL),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ]
        return components.url!
    }

    func exchange(code: String, verifier: String) async throws -> AuthSession {
        let data = try await request("auth/v1/token", method: "POST",
                                     query: [URLQueryItem(name: "grant_type", value: "pkce")],
                                     body: ["auth_code": code, "code_verifier": verifier])
        return try Self.decodeSession(data)
    }

    func refresh(_ refreshToken: String) async throws -> AuthSession {
        let data = try await request("auth/v1/token", method: "POST",
                                     query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
                                     body: ["refresh_token": refreshToken])
        return try Self.decodeSession(data)
    }

    /// Sends a six-digit code to the address. A new address gets an account on the first correct code.
    func sendEmailCode(to email: String) async throws {
        _ = try await request("auth/v1/otp", method: "POST", body: ["email": email, "create_user": true])
    }

    func verifyEmailCode(email: String, code: String) async throws -> AuthSession {
        let data = try await request("auth/v1/verify", method: "POST",
                                     body: ["type": "email", "email": email, "token": code])
        return try Self.decodeSession(data)
    }

    func signOut(token: String) async {
        _ = try? await request("auth/v1/logout", method: "POST", token: token)
    }

    static func decodeSession(_ data: Data) throws -> AuthSession {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any],
              let id = (user["id"] as? String).flatMap(UUID.init(uuidString:))
        else { throw ServerError(status: 0, code: "bad_response") }
        let lifetime = (object["expires_in"] as? Double) ?? 3600
        return AuthSession(accessToken: access, refreshToken: refresh,
                           expiresAt: .now.addingTimeInterval(lifetime), userID: id)
    }

    // MARK: Database

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

    func profile(token: String) async throws -> AccountProfile? {
        let data = try await request("rest/v1/profiles", query: [URLQueryItem(name: "select", value: "id,display_name,handle_number,name_changed_at,invite_code")],
                                     token: token)
        return try Self.decoder.decode([AccountProfile].self, from: data).first
    }

    func createProfile(name: String, birthYear: Int, birthMonth: Int, token: String) async throws -> AccountProfile {
        let data = try await request("rest/v1/rpc/create_profile", method: "POST",
                                     body: ["p_display_name": name, "p_birth_year": birthYear,
                                            "p_birth_month": birthMonth, "p_terms_accepted": true], token: token)
        return try Self.decoder.decode(AccountProfile.self, from: data)
    }

    func renameProfile(to name: String, token: String) async throws -> AccountProfile {
        let data = try await request("rest/v1/rpc/rename_profile", method: "POST",
                                     body: ["p_display_name": name], token: token)
        return try Self.decoder.decode(AccountProfile.self, from: data)
    }

    func deleteAccount(token: String) async throws {
        _ = try await request("rest/v1/rpc/delete_account", method: "POST", body: [:], token: token)
    }

    func serverTime(token: String) async throws -> Date {
        let data = try await request("rest/v1/rpc/server_time", method: "POST", body: [:], token: token)
        let text = try Self.decoder.decode(String.self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: text) else { throw ServerError(status: 0, code: "bad_response") }
        return date
    }
}
