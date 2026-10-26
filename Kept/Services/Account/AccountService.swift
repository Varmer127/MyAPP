import AuthenticationServices
import Foundation
import Observation
import OSLog
import UIKit

/// The optional account. Without it the app works exactly as before; with it the social parts unlock.
@MainActor @Observable
final class AccountService {
    static let shared = AccountService()

    enum State: Equatable {
        /// Not looked at yet (app just started).
        case unknown
        case signedOut
        /// Signed in with Discord, but no profile yet: name, age and terms still to be given.
        case needsProfile
        case ready(AccountProfile)
        /// Signed in, but the server could not be reached or answered with an error: the profile is loaded again on request.
        case unavailable
    }

    private(set) var state: State = .unknown
    /// True while a call to the server is running, so a button can show it.
    private(set) var isWorking = false
    /// Difference between the server clock and the phone clock. Zero until the first successful measurement.
    private(set) var serverOffset: TimeInterval = 0

    private static let sessionKey = "session"
    private static let logger = Logger(subsystem: "cz.philipstryka.kept", category: "account")

    private let client = ServerClient()
    private var session: AuthSession?
    private var authSession: ASWebAuthenticationSession?
    private let presenter = SignInPresenter()

    var profile: AccountProfile? {
        if case .ready(let profile) = state { return profile }
        return nil
    }
    var isSignedIn: Bool { state != .signedOut && state != .unknown }

    /// The time according to the server where known, otherwise the phone clock.
    var now: Date { Date.now.addingTimeInterval(serverOffset) }

    // MARK: Start

    /// Called once at launch: picks up a saved sign-in, if there is one.
    func restore() async {
        guard state == .unknown else { return }
        guard let data = KeychainStore.load(Self.sessionKey),
              let saved = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            state = .signedOut
            return
        }
        session = saved
        await loadProfile()
    }

    /// Asks the server again who this is, for example when it says a profile already exists.
    func reload() async { await loadProfile() }

    private func loadProfile() async {
        do {
            let token = try await validToken()
            if let profile = try await client.profile(token: token) {
                state = .ready(profile)
                await measureServerTime(token: token)
            } else {
                state = .needsProfile
            }
        } catch let error as ServerError where error.isUnauthorized {
            clearSession()
        } catch {
            // The sign-in itself is fine, so it is kept; the screens offer to try again.
            Self.logger.error("Profile not loaded: \(String(describing: type(of: error)))")
            state = session == nil ? .signedOut : .unavailable
        }
    }

    // MARK: Sign-in

    func signInWithDiscord() async throws {
        isWorking = true
        defer { isWorking = false }
        let pkce = PKCE()
        let url = client.authorizeURL(provider: "discord", challenge: pkce.challenge)
        let callback = try await present(url)
        guard let parsed = AuthCallback.parse(callback) else { throw ServerError(status: 0, code: "bad_response") }
        switch parsed {
        case .failure:
            throw ServerError(status: 0, code: "sign_in_failed")
        case .code(let code):
            let fresh = try await client.exchange(code: code, verifier: pkce.verifier)
            store(fresh)
            await loadProfile()
            if state == .unavailable { throw ServerError(status: 0, code: "profile_unavailable") }
        }
    }

    // MARK: E-mail

    /// Step one: the code goes to the address.
    func requestEmailCode(to email: String) async throws {
        isWorking = true
        defer { isWorking = false }
        try await client.sendEmailCode(to: email.trimmingCharacters(in: .whitespaces).lowercased())
    }

    /// Step two: the code from the e-mail signs the person in (and creates the account for a new address).
    func confirmEmailCode(email: String, code: String) async throws {
        isWorking = true
        defer { isWorking = false }
        let fresh = try await client.verifyEmailCode(email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                                                     code: code.trimmingCharacters(in: .whitespaces))
        store(fresh)
        await loadProfile()
        if state == .unavailable { throw ServerError(status: 0, code: "profile_unavailable") }
    }

    private func present(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let web = ASWebAuthenticationSession(url: url, callbackURLScheme: ServerConfig.callbackScheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: CancellationError())
                } else {
                    continuation.resume(throwing: ServerError(status: 0, code: "sign_in_failed"))
                }
            }
            web.presentationContextProvider = presenter
            authSession = web
            if !web.start() {
                continuation.resume(throwing: ServerError(status: 0, code: "sign_in_failed"))
            }
        }
    }

    // MARK: Profile

    func createProfile(name: String, birthYear: Int, birthMonth: Int) async throws {
        try await authorized { token in
            let profile = try await self.client.createProfile(name: name, birthYear: birthYear, birthMonth: birthMonth, token: token)
            self.state = .ready(profile)
            await self.measureServerTime(token: token)
        }
    }

    func rename(to name: String) async throws {
        try await authorized { token in
            self.state = .ready(try await self.client.renameProfile(to: name, token: token))
        }
    }

    func deleteAccount() async throws {
        try await authorized { token in
            try await self.client.deleteAccount(token: token)
        }
        clearSession()
    }

    func signOut() async {
        if let token = session?.accessToken { await client.signOut(token: token) }
        clearSession()
    }

    // MARK: Helpers

    /// Runs a call to the server with a valid sign-in. When the server no longer accepts it, the app signs out.
    func perform<T>(_ work: (String) async throws -> T) async throws -> T {
        do {
            return try await work(try await validToken())
        } catch let error as ServerError where error.isUnauthorized {
            clearSession()
            throw error
        }
    }

    private func authorized(_ work: @escaping (String) async throws -> Void) async throws {
        isWorking = true
        defer { isWorking = false }
        do {
            try await work(try await validToken())
        } catch let error as ServerError where error.isUnauthorized {
            clearSession()
            throw error
        }
    }

    private func validToken() async throws -> String {
        guard var current = session else { throw ServerError(status: 401, code: "not_signed_in") }
        if current.needsRefresh {
            current = try await client.refresh(current.refreshToken)
            store(current)
        }
        return current.accessToken
    }

    private func store(_ fresh: AuthSession) {
        session = fresh
        if let data = try? JSONEncoder().encode(fresh) { KeychainStore.save(data, for: Self.sessionKey) }
    }

    private func clearSession() {
        session = nil
        KeychainStore.delete(Self.sessionKey)
        serverOffset = 0
        state = .signedOut
    }

    /// Half of the round trip is taken as the time the answer needed to travel.
    private func measureServerTime(token: String) async {
        let sent = Date.now
        guard let server = try? await client.serverTime(token: token) else { return }
        let received = Date.now
        let phoneAtServer = sent.addingTimeInterval(received.timeIntervalSince(sent) / 2)
        serverOffset = server.timeIntervalSince(phoneAtServer)
    }
}

/// Tells the system which window the sign-in page slides over.
private final class SignInPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
