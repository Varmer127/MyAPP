import SwiftUI

/// The signed-in account: the identifier, renaming, signing out and deleting the account.
struct AccountView: View {
    private let account = AccountService.shared
    @State private var newName = ""
    @State private var errorText: LocalizedStringKey?
    @State private var confirmsDelete = false
    @State private var confirmsSignOut = false
    @State private var copied = false

    private var profile: AccountProfile? { account.profile }

    /// Renaming is allowed once a week; the server enforces it, this only says so before the person tries.
    private var nextRename: Date? {
        profile?.nameChangedAt.map { $0.addingTimeInterval(7 * 86_400) }.flatMap { $0 > account.now ? $0 : nil }
    }

    var body: some View {
        Form {
            if let profile {
                Section {
                    LabeledContent("Tvoje označení") {
                        Text(profile.handle).textSelection(.enabled)
                    }
                    Button {
                        UIPasteboard.general.string = profile.handle
                        Haptics.light()
                        copied = true
                    } label: {
                        Label(copied ? "Zkopírováno" : "Zkopírovat označení", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                } header: {
                    Text("Účet")
                } footer: {
                    Text("Takhle tě přátelé najdou. Nikdo tě nenajde jen podle jména, potřebuje celé označení nebo tvůj QR kód.")
                }
                .listRowBackground(Theme.card)

                Section {
                    NavigationLink {
                        DoNotDisturbView()
                    } label: {
                        LabeledContent {
                            Text(profile.dndActive ? "Zapnuto" : "Vypnuto").foregroundStyle(Theme.textSecondary)
                        } label: {
                            Label("Nerušit", systemImage: "moon")
                        }
                    }
                } footer: {
                    Text("Přátelé uvidí, že je neruším, a nemůžou mě šťouchnout.")
                }
                .listRowBackground(Theme.card)

                Section {
                    TextField("Nové jméno", text: $newName)
                        .autocorrectionDisabled()
                        .onChange(of: newName) { _, new in
                            if new.count > 24 { newName = String(new.prefix(24)) }
                        }
                    Button("Změnit jméno") { rename() }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || account.isWorking || nextRename != nil)
                    if let errorText {
                        Text(errorText).scaledFont(.caption).foregroundStyle(Theme.red)
                    }
                } header: {
                    Text("Jméno")
                } footer: {
                    if let nextRename {
                        Text("Jméno jde změnit zase \(nextRename.formatted(.dateTime.day().month().hour().minute().locale(.app))).")
                    } else {
                        Text("Jméno jde změnit nejvýš jednou za 7 dní. Čtyři čísla zůstanou, pokud jsou u nového jména volná.")
                    }
                }
                .listRowBackground(Theme.card)

                Section {
                    Button("Odhlásit se") { confirmsSignOut = true }
                    Button("Smazat účet", role: .destructive) { confirmsDelete = true }
                        .foregroundStyle(Theme.red)
                } footer: {
                    Text("Odhlášení nic nesmaže, po přihlášení je všechno zpět. Smazání účtu odstraní profil a všechno, co k němu patří, na serveru. Data v telefonu zůstanou.")
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Účet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .alert("Odhlásit se?", isPresented: $confirmsSignOut) {
            Button("Odhlásit se") { Task { await account.signOut() } }
            Button("Zůstat", role: .cancel) {}
        } message: {
            Text("Sociální části se zamknou. Přihlásit se můžeš kdykoli znovu.")
        }
        .alert("Smazat účet?", isPresented: $confirmsDelete) {
            Button("Smazat účet", role: .destructive) {
                Task {
                    do { try await account.deleteAccount() } catch { errorText = "Účet se nepodařilo smazat. Zkus to prosím znovu." }
                }
            }
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Zmizí tvůj profil, přátelé i sázky. Nejde to vrátit.")
        }
    }

    private func rename() {
        errorText = nil
        Task {
            do {
                try await account.rename(to: newName.trimmingCharacters(in: .whitespaces))
                newName = ""
                Haptics.success()
            } catch let error as ServerError {
                switch error.code {
                case "renamed_too_recently": errorText = "Jméno jsi měnil/a nedávno. Zkus to později."
                case "invalid_name": errorText = "Jméno má mít 1 až 24 znaků."
                default: errorText = "Jméno se nepodařilo změnit. Zkus to prosím znovu."
                }
            } catch {
                errorText = "Jméno se nepodařilo změnit. Zkontroluj připojení."
            }
        }
    }
}
