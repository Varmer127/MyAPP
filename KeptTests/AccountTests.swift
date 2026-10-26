import Foundation
import Testing
@testable import Kept

struct AccountTests {
    @Test func pkceChallengeMatchesTheStandardExample() {
        // Test vector from RFC 7636, appendix B.
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
        #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func pkceVerifiersDifferAndUseSafeCharacters() {
        let first = PKCE(), second = PKCE()
        #expect(first.verifier != second.verifier)
        #expect(first.verifier.range(of: #"^[A-Za-z0-9_-]{43,128}$"#, options: .regularExpression) != nil)
    }

    @Test func callbackWithCodeIsRecognised() {
        let url = URL(string: "cz.philipstryka.kept://login-callback?code=abc123")!
        #expect(AuthCallback.parse(url) == .code("abc123"))
    }

    @Test func callbackWithErrorIsAFailure() {
        let url = URL(string: "cz.philipstryka.kept://login-callback?error=access_denied&error_description=No")!
        #expect(AuthCallback.parse(url) == .failure("access_denied"))
    }

    @Test func callbackWithoutCodeIsIgnored() {
        #expect(AuthCallback.parse(URL(string: "cz.philipstryka.kept://login-callback")!) == nil)
    }

    @Test func serverErrorsKeepOnlyAShortWord() {
        let known = ServerClient.error(status: 400, data: Data(#"{"message":"too_young","code":"22023"}"#.utf8))
        #expect(known == ServerError(status: 400, code: "too_young"))
        // Anything that is not a short word could contain private text and is not passed on.
        let long = ServerClient.error(status: 500, data: Data(#"{"message":"duplicate key value violates unique constraint"}"#.utf8))
        #expect(long.code == "unknown")
    }

    @Test func unauthorizedErrorsAreRecognised() {
        #expect(ServerError(status: 401, code: "unknown").isUnauthorized)
        #expect(ServerError(status: 400, code: "invalid_grant").isUnauthorized)
        #expect(!ServerError(status: 400, code: "too_young").isUnauthorized)
    }

    @Test func tokenResponseBecomesASession() throws {
        let json = #"{"access_token":"a","refresh_token":"r","expires_in":3600,"user":{"id":"11111111-2222-3333-4444-555555555555"}}"#
        let session = try ServerClient.decodeSession(Data(json.utf8))
        #expect(session.accessToken == "a")
        #expect(session.refreshToken == "r")
        #expect(!session.needsRefresh)
        #expect(session.userID == UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
    }

    @Test func incompleteTokenResponseIsRejected() {
        #expect(throws: ServerError.self) { try ServerClient.decodeSession(Data(#"{"access_token":"a"}"#.utf8)) }
    }

    @Test func handleIsNameAndNumber() {
        let profile = AccountProfile(id: UUID(), displayName: "Jana", handleNumber: 4827, nameChangedAt: nil, inviteCode: nil)
        #expect(profile.handle == "Jana#4827")
    }

    @Test func authorizeURLCarriesTheProofAndTheReturnAddress() {
        let url = ServerClient().authorizeURL(provider: "discord", challenge: "xyz")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.contains { $0.name == "provider" && $0.value == "discord" })
        #expect(items.contains { $0.name == "code_challenge" && $0.value == "xyz" })
        #expect(items.contains { $0.name == "code_challenge_method" && $0.value == "s256" })
        #expect(items.contains { $0.name == "redirect_to" && $0.value == ServerConfig.redirectURL })
    }

    @Test func plausibleEmailAddresses() {
        #expect(EmailAddress.isPlausible("jana@example.cz"))
        #expect(EmailAddress.isPlausible("  jana.novakova+kept@mail.example.com "))
        #expect(!EmailAddress.isPlausible("jana"))
        #expect(!EmailAddress.isPlausible("jana@"))
        #expect(!EmailAddress.isPlausible("@example.cz"))
        #expect(!EmailAddress.isPlausible("jana@example"))
        #expect(!EmailAddress.isPlausible("jana novakova@example.cz"))
    }
}

struct FriendLinkTests {
    @Test func codeRoundTripsThroughTheLink() {
        let url = FriendLink.url(code: "0123456789ab")!
        #expect(url.absoluteString == "kept://friend/0123456789ab")
        #expect(FriendLink.code(from: url) == "0123456789ab")
    }

    @Test func foreignOrMalformedLinksAreIgnored() {
        #expect(FriendLink.code(from: URL(string: "https://example.com/friend/0123456789ab")!) == nil)
        #expect(FriendLink.code(from: URL(string: "kept://friend/not-a-code")!) == nil)
        #expect(FriendLink.code(from: URL(string: "kept://other/0123456789ab")!) == nil)
    }

    @Test func onlyWholeIdentifiersAndCodesAreSearched() {
        #expect(FriendLink.isSearchable("Jana#4827"))
        #expect(!FriendLink.isSearchable("0123456789ab"))
        #expect(!FriendLink.isSearchable("Jana"))
        #expect(!FriendLink.isSearchable("Jana#48"))
        #expect(!FriendLink.isSearchable(""))
    }
}

struct PokeAndDoNotDisturbTests {
    @Test func pokeTextRules() {
        #expect(PokeText.isSendable("Jak jde slib?"))
        #expect(!PokeText.isSendable("   "))
        #expect(!PokeText.isSendable(String(repeating: "x", count: 101)))
        #expect(PokeText.isSendable(String(repeating: "x", count: 100)))
    }

    @Test func linksAreRecognised() {
        #expect(PokeText.containsLink("mrkni na https://example.com"))
        #expect(PokeText.containsLink("www.kept.cz"))
        #expect(PokeText.containsLink("viz kept.cz"))
        #expect(!PokeText.containsLink("Dnes to dáš, i když je to těžké."))
        #expect(!PokeText.isSendable("koukni na kept.cz"))
    }

    @Test func customReasonIsAFewWords() {
        #expect(DNDReason.isValidCustom("na horách bez signálu"))
        #expect(!DNDReason.isValidCustom("jedna dva tři čtyři pět šest sedm"))
        #expect(!DNDReason.isValidCustom("  "))
        #expect(DNDReason.wordCount("na   horách") == 2)
    }
}
