import SwiftUI

/// A friend's QR code opens the app with `kept://friend/<code>`. This shows the add-friend sheet for it,
/// or the registration first when there is no account yet.
@MainActor @Observable
final class FriendLinkInbox {
    static let shared = FriendLinkInbox()
    var code: String?
}

struct FriendLinkHandler: ViewModifier {
    private let inbox = FriendLinkInbox.shared
    private let account = AccountService.shared
    @State private var showsAdd = false
    @State private var showsRegistration = false

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                guard let code = FriendLink.code(from: url) else { return }
                inbox.code = code
                present()
            }
            .onChange(of: account.state) { _, _ in
                // Signed in through the registration the link started: carry on with the link.
                if inbox.code != nil, case .ready = account.state, showsRegistration == false { present() }
            }
            .sheet(isPresented: $showsAdd, onDismiss: { inbox.code = nil }) {
                AddFriendView(initialCode: inbox.code)
            }
            .sheet(isPresented: $showsRegistration) {
                RegistrationView(onDone: { showsAdd = inbox.code != nil })
            }
    }

    private func present() {
        if case .ready = account.state { showsAdd = true } else { showsRegistration = true }
    }
}
