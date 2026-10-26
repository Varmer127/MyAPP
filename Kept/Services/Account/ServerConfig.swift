import Foundation

/// Where the optional social layer lives. Both values are meant to be public: the publishable key only opens
/// what the access rules of the database allow, and the rules (not the key) decide who sees what.
enum ServerConfig {
    // Development project. The production project gets its own values in the final phase.
    static let url = URL(string: "https://fsaefkdsjcecebhoqagq.supabase.co")!
    static let publishableKey = "sb_publishable_PHSzVCcpjgKb4X8qg9xHVw_r-R_2gK9"

    /// E-mail sign-in with a code. Off until the project sends its own e-mails: the built-in sender cannot carry the code.
    static let emailLoginEnabled = false

    static let callbackScheme = "cz.philipstryka.kept"
    static let redirectURL = "\(callbackScheme)://login-callback"
}
