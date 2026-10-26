import CryptoKit
import Foundation

/// The proof that ties a sign-in to the app that started it, so a stolen redirect cannot be used by someone else.
struct PKCE {
    let verifier: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 48)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        // Random bytes are the whole point: without them the sign-in must not start.
        precondition(status == errSecSuccess, "No secure random bytes")
        verifier = Self.base64URL(Data(bytes))
    }

    /// For tests with a known verifier.
    init(verifier: String) { self.verifier = verifier }

    var challenge: String { Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// What the sign-in page sends back to the app.
enum AuthCallback: Equatable {
    case code(String)
    case failure(String)

    static func parse(_ url: URL) -> AuthCallback? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") ?? value("error_code") { return .failure(error) }
        if let code = value("code"), !code.isEmpty { return .code(code) }
        return nil
    }
}
