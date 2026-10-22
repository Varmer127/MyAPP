import SwiftUI
import SwiftData
import LocalAuthentication

/// "My data": one file with everything the user entered, handed over through the system share sheet.
/// The diary is only included when the user asks, and behind Face ID or the passcode when a lock is on.
struct DataExportSection: View {
    let settings: UserSettings
    @Query private var tasks: [TaskItem]
    @Query private var plans: [WeeklyPlan]
    @Query private var failures: [FailureRecord]
    @Query private var diary: [DiaryEntry]
    @State private var includesDiary = false
    @State private var exportURL: URL?
    @State private var failed = false

    var body: some View {
        Section {
            Toggle("Zahrnout deník", isOn: $includesDiary)
                .tint(Theme.textSecondary)
                .onChange(of: includesDiary) { _, _ in exportURL = nil }
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("ULOŽIT NEBO POSLAT SOUBOR", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            } else {
                Button {
                    Task { await prepare() }
                } label: {
                    Label("PŘIPRAVIT EXPORT", systemImage: "tray.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 14))
            }
        } header: {
            Text("Moje data")
        } footer: {
            Text("Sliby, týdny a selhání jako jeden soubor, který si můžeš nechat jako zálohu. Fotky v něm nejsou. Soubor jde jen tam, kam ho pošleš sám přes systémové sdílení.")
        }
        .listRowBackground(Theme.card)
        .alert("Export se nepovedl", isPresented: $failed) {
            Button("Rozumím", role: .cancel) {}
        } message: {
            Text("Zkus to prosím znovu a zkontroluj volné místo v telefonu.")
        }
    }

    private func prepare() async {
        if includesDiary, settings.diaryLockEnabled || settings.appLockEnabled {
            guard await authenticate() else { return }
        }
        let file = DataExport.build(tasks: tasks, plans: plans, failures: failures, diary: includesDiary ? diary : nil)
        do {
            exportURL = try DataExport.write(file)
            Haptics.success()
        } catch {
            failed = true
        }
    }

    private func authenticate() async -> Bool {
        await withCheckedContinuation { continuation in
            LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Zahrnout deník do exportu") { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
