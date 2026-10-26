import CoreImage.CIFilterBuiltins
import SwiftUI

/// Two ways to meet: show your own QR code, or enter a friend's identifier or code.
struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    var initialCode: String?

    private let account = AccountService.shared
    private let friends = FriendsService.shared
    @State private var mode: Mode
    @State private var query = ""
    @State private var found: FoundPerson?
    @State private var message: LocalizedStringKey?
    @State private var messageIsError = false
    @State private var isBusy = false
    @State private var confirmsRotate = false

    private enum Mode: String, CaseIterable, Identifiable {
        case add, mine
        var id: String { rawValue }
    }

    init(initialCode: String? = nil) {
        self.initialCode = initialCode
        _mode = State(initialValue: initialCode == nil ? .mine : .add)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Co chceš", selection: $mode) {
                        Text("Můj QR kód").tag(Mode.mine)
                        Text("Přidat").tag(Mode.add)
                    }
                    .pickerStyle(.segmented)
                    switch mode {
                    case .mine: mine
                    case .add: add
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Přidat přítele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } } }
            .task {
                // A scanned QR code looks the person up directly; typing only accepts the whole identifier.
                if let initialCode { await search(initialCode) }
            }
        }
        .appAppearance()
    }

    // MARK: My code

    private var mine: some View {
        VStack(alignment: .center, spacing: 16) {
            if let profile = account.profile {
                if let code = profile.inviteCode, let url = FriendLink.url(code: code), let image = Self.qr(for: url.absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .accessibilityLabel("Tvůj QR kód")
                    Text("Kamarád ho naskenuje foťákem v iPhonu a otevře se Kept.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 4) {
                    Text("Tvoje označení").labelStyle()
                    Text(profile.handle)
                        .scaledFont(.title, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                }
                .padding(.top, 4)
                if let code = profile.inviteCode {
                    ShareLink(item: "Jsem v Kept jako \(profile.handle). Najdeš mě podle tohohle označení.") {
                        Label("Poslat označení", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("Vyměnit QR kód") { confirmsRotate = true }
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)
                Text("Starý QR kód přestane fungovat. Přátelé, které už máš, zůstanou.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .alert("Vyměnit QR kód?", isPresented: $confirmsRotate) {
            Button("Vyměnit") { Task { try? await friends.rotateInviteCode() } }
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Starý QR kód přestane fungovat. Přátelé, které už máš, zůstanou.")
        }
    }

    // MARK: Add

    private var add: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Napiš celé označení kamaráda, třeba Jana#4827, nebo naskenuj jeho QR kód foťákem v iPhonu. Podle samotného jména nikoho nenajdeš.")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Jana#4827", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { if FriendLink.isSearchable(query) { await search(query) } } }
                .scaledFont(.body)
                .padding(14)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            Button { Task { await search(query) } } label: {
                Text(isBusy ? "HLEDÁM…" : "NAJÍT")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!FriendLink.isSearchable(query) || isBusy)

            if let found {
                HStack(spacing: 12) {
                    Avatar(initial: found.initial)
                    Text(found.displayName)
                        .scaledFont(.heading, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .card()
                Button { Task { await send(found) } } label: {
                    Text(isBusy ? "POSÍLÁM…" : "POSLAT ŽÁDOST")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isBusy)
            }
            if let message {
                Text(message)
                    .scaledFont(.caption)
                    .foregroundStyle(messageIsError ? Theme.red : Theme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Actions

    private func search(_ text: String) async {
        isBusy = true
        defer { isBusy = false }
        message = nil
        found = nil
        do {
            if let person = try await friends.find(text) {
                found = person
            } else {
                show("Nikoho jsme nenašli. Zkontroluj označení.", error: true)
            }
        } catch let error as ServerError where error.code == "rate_limited" {
            show("Moc hledání za sebou. Zkus to prosím za chvíli.", error: true)
        } catch {
            show("Hledání se nepovedlo. Zkontroluj připojení.", error: true)
        }
    }

    private func send(_ person: FoundPerson) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let nowFriends = try await friends.request(person)
            Haptics.success()
            found = nil
            query = ""
            show(nowFriends ? "Hotovo, jste přátelé." : "Žádost je odeslaná. Až ji \(person.displayName) přijme, uvidíš ho v seznamu.", error: false)
        } catch let error as ServerError {
            switch error.code {
            case "already_friends": show("Už jste přátelé.", error: true)
            case "already_requested": show("Žádost už jsi poslal. Počkej na odpověď.", error: true)
            case "not_found": show("Tohle se nepovedlo. Zkus to znovu později.", error: true)
            case "too_many_requests": show("Máš moc nevyřízených žádostí. Počkej, až je někdo přijme.", error: true)
            case "rate_limited": show("Moc žádostí za sebou. Zkus to prosím za chvíli.", error: true)
            default: show("Žádost se nepodařilo poslat.", error: true)
            }
        } catch {
            show("Žádost se nepodařilo poslat. Zkontroluj připojení.", error: true)
        }
    }

    private func show(_ text: LocalizedStringKey, error: Bool) {
        message = text
        messageIsError = error
    }

    /// A QR code as an image, drawn crisp by scaling up the small bitmap.
    static func qr(for text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
