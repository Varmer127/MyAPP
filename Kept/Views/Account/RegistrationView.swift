import SwiftUI

/// Registration and sign-in in one place: Discord first, then (for a new account) name, age and the community rules.
/// Every locked part of the app and the onboarding lead here, so there is a single flow to keep right.
struct RegistrationView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called when the account is ready, so the caller can carry on (for example the onboarding goes to the next step).
    var onDone: () -> Void = {}

    private let account = AccountService.shared
    @State private var name = ""
    @State private var birthMonth: Int?
    @State private var birthYear: Int?
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var resendAt = Date.distantPast
    @FocusState private var focus: Field?
    private enum Field { case email, code }
    @State private var errorText: LocalizedStringKey?
    private static let nameLimit = 24

    private var years: [Int] {
        let current = Calendar.app.component(.year, from: .now)
        return Array((current - 100...current).reversed())
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && birthMonth != nil && birthYear != nil && !account.isWorking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch account.state {
                    case .unknown, .signedOut: signInStep
                    case .needsProfile: profileStep
                    case .unavailable: unavailableStep
                    case .ready(let profile): doneStep(profile)
                    }
                    if let errorText {
                        Text(errorText)
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 22)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Přátelé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .ready = account.state {} else { Button("Zavřít") { dismiss() } }
                }
            }
        }
        .appAppearance()
    }

    // MARK: Steps

    private var signInStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("ÚČET JE VOLITELNÝ", "Kept s přáteli.",
                    "Sdílej týden, pošťouchávejte se a sázejte se o body. Bez účtu Kept funguje dál jako dnes.")
            VStack(alignment: .leading, spacing: 10) {
                bullet("Deník, váha, zdraví a fotky zůstanou jen v tvém telefonu.")
                bullet("Nic se nesdílí, dokud to sám nezapneš.")
                bullet("Účet smažeš kdykoli v Nastavení.")
            }
            .card()
            VStack(alignment: .leading, spacing: 18) {
                Button { signIn() } label: {
                    Text(account.isWorking ? "ČEKÁM NA DISCORD…" : "POKRAČOVAT PŘES DISCORD")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(account.isWorking)
                Text("Registrace i přihlášení na dalším telefonu probíhá stejně. Discord se tě zeptá, jen aby Kept věděl, že jsi to ty; heslo od Discordu se k Kept nedostane.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if ServerConfig.emailLoginEnabled { emailBlock }
            }
        }
    }

    /// No password: the address gets a six-digit code, and the code is the sign-in.
    private var emailBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle().fill(Theme.border).frame(height: 1)
                Text("nebo e-mailem").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                Rectangle().fill(Theme.border).frame(height: 1)
            }
            .padding(.vertical, 4)
            if codeSent {
                Text("Poslali jsme šestimístný kód na \(email). Zadej ho sem. Když nepřijde, mrkni do nevyžádané pošty.")
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Kód z e-mailu", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focus, equals: .code)
                    .scaledFont(.title, weight: .heavy)
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    .onChange(of: code) { _, new in
                        let digits = String(new.filter(\.isNumber).prefix(6))
                        if digits != new { code = digits }
                        if digits.count == 6 { confirmCode() }
                    }
                Button { confirmCode() } label: {
                    Text(account.isWorking ? "OVĚŘUJI…" : "POTVRDIT KÓD")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(code.count != 6 || account.isWorking)
                HStack {
                    Button("Změnit e-mail") { codeSent = false; code = "" }
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let wait = Int(resendAt.timeIntervalSince(context.date).rounded(.up))
                        Button(wait > 0 ? "Poslat znovu za \(wait) s" : "Poslat znovu") { sendCode() }
                            .disabled(wait > 0 || account.isWorking)
                    }
                }
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
            } else {
                TextField("tvuj@email.cz", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .scaledFont(.body)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                Button { sendCode() } label: {
                    Text(account.isWorking ? "POSÍLÁM…" : "POSLAT KÓD")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(!EmailAddress.isPlausible(email) || account.isWorking)
                Text("Bez hesla. Pošleme ti kód a tím se přihlásíš. Stejně se přihlásíš i na dalším telefonu.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("SKORO HOTOVO", "Jak se budeš jmenovat?",
                    "Takhle tě uvidí přátelé. Ke jménu ti Kept přidělí čtyři čísla, aby se nepletli dva stejní.")
            VStack(alignment: .leading, spacing: 8) {
                TextField("Jméno pro přátele", text: $name)
                    .textContentType(.nickname)
                    .autocorrectionDisabled()
                    .scaledFont(.body)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    .onChange(of: name) { _, new in
                        if new.count > Self.nameLimit { name = String(new.prefix(Self.nameLimit)) }
                    }
                Text("Nejvýš \(Self.nameLimit) znaků. Jméno půjde změnit, nejvýš jednou za 7 dní.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Datum narození").labelStyle()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Měsíc").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                        Picker("Měsíc", selection: $birthMonth) {
                            Text("—").tag(Int?.none)
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)").tag(Int?.some(month))
                            }
                        }
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rok").scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                        Picker("Rok", selection: $birthYear) {
                            Text("—").tag(Int?.none)
                            ForEach(years, id: \.self) { year in
                                Text(String(year)).tag(Int?.some(year))
                            }
                        }
                        .labelsHidden()
                    }
                    Spacer()
                }
                .pickerStyle(.menu)
                .tint(Theme.textPrimary)
                Text("Zadej své skutečné datum narození. Nikdo ho neuvidí a Kept si ho neuloží.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Button { create() } label: {
                Text(account.isWorking ? "VYTVÁŘÍM…" : "VYTVOŘIT ÚČET")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canCreate)
            Text("Vytvořením účtu souhlasíš s pravidly Kept: žádné urážky ani výhrůžky, žádné cizí údaje a fotky. Nahlášený obsah může být smazán a účet zablokován.")
                .scaledFont(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Zrušit a odhlásit") {
                Task { await account.signOut() }
            }
            .scaledFont(.body)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    /// The sign-in worked but the profile could not be read: nothing is lost, it only has to be asked for again.
    private var unavailableStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("PŘIHLÁŠENO", "Účet se nenačetl.",
                    "Přihlášení prošlo, ale od serveru nepřišla odpověď. Zkontroluj připojení a zkus to znovu.")
            Button { Task { await account.reload() } } label: {
                Text(account.isWorking ? "NAČÍTÁM…" : "ZKUSIT ZNOVU")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Odhlásit se") { Task { await account.signOut() } }
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func doneStep(_ profile: AccountProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("HOTOVO", "Ahoj, \(profile.displayName).",
                    "Tohle je tvoje označení. Přátelé tě podle něj najdou.")
            Text(profile.handle)
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .card()
                .textSelection(.enabled)
            Button("POKRAČOVAT") {
                onDone()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000)))
        }
    }

    // MARK: Pieces

    private func heading(_ kicker: LocalizedStringKey, _ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker).labelStyle()
            Text(title)
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Theme.green).frame(width: 6, height: 6).padding(.top, 7)
            Text(text)
                .scaledFont(.body)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func signIn() {
        errorText = nil
        Task {
            do {
                try await account.signInWithDiscord()
            } catch is CancellationError {
                // The person closed the sign-in page: nothing to say.
            } catch let error as ServerError where error.code == "profile_unavailable" {
                // The screen switches to the "try again" step by itself.
            } catch {
                errorText = "Přihlášení se nepovedlo. Zkus to prosím znovu."
            }
        }
    }

    private func sendCode() {
        errorText = nil
        Task {
            do {
                try await account.requestEmailCode(to: email)
                codeSent = true
                code = ""
                resendAt = Date.now.addingTimeInterval(30)
                focus = .code
            } catch let error as ServerError where error.status == 429 {
                errorText = "Moc pokusů za sebou. Zkus to prosím za chvíli."
            } catch {
                errorText = "Kód se nepodařilo poslat. Zkontroluj adresu a připojení."
            }
        }
    }

    private func confirmCode() {
        guard code.count == 6, !account.isWorking else { return }
        errorText = nil
        Task {
            do {
                try await account.confirmEmailCode(email: email, code: code)
            } catch let error as ServerError where error.status == 429 {
                errorText = "Moc pokusů za sebou. Zkus to prosím za chvíli."
            } catch let error as ServerError where error.code == "profile_unavailable" {
                // The screen switches to the "try again" step by itself.
            } catch {
                code = ""
                errorText = "Kód nesedí nebo vypršel. Zkus to znovu, nebo pošli nový."
            }
        }
    }

    private func create() {
        guard let birthMonth, let birthYear else { return }
        errorText = nil
        Task {
            do {
                try await account.createProfile(name: name.trimmingCharacters(in: .whitespaces),
                                                birthYear: birthYear, birthMonth: birthMonth)
                Haptics.success()
            } catch let error as ServerError {
                switch error.code {
                case "too_young":
                    errorText = "Přátelé jsou od 16 let. Zkontroluj datum narození. Zbytek Kept funguje bez omezení."
                case "invalid_name": errorText = "Jméno má mít 1 až 24 znaků."
                case "invalid_birth_date": errorText = "Zkontroluj datum narození."
                case "profile_exists": await account.reload()
                default: errorText = "Účet se nepodařilo vytvořit. Zkus to prosím znovu."
                }
            } catch {
                errorText = "Účet se nepodařilo vytvořit. Zkontroluj připojení a zkus to znovu."
            }
        }
    }
}
