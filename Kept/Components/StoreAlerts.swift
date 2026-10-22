import SwiftUI

/// What the user is told when the data layer has a problem: a store that could not be opened (the app started clean,
/// the old files are kept), and a change that could not be written.
struct StoreAlerts: ViewModifier {
    /// Filled when the data could not be opened and the app had to start clean; shown to the user once.
    @AppStorage(AppStore.recoveryKey) private var storeRecovery = ""
    @State private var saveFailed = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .persistenceFailed).receive(on: RunLoop.main)) { _ in
                saveFailed = true
            }
            .alert("Změnu se nepodařilo uložit", isPresented: $saveFailed) {
                Button("Rozumím", role: .cancel) {}
            } message: {
                Text("Zkus to prosím znovu. Pokud se to bude opakovat, zkontroluj volné místo v telefonu.")
            }
            .alert("Data se nepodařilo otevřít", isPresented: Binding(
                get: { !storeRecovery.isEmpty },
                set: { if !$0 { storeRecovery = "" } })) {
                Button("Rozumím", role: .cancel) {}
            } message: {
                Text("Kept nemohl načíst tvoje uložená data, a tak začal s čistou databází. Původní soubory jsou uschované a nic se nesmazalo, takže jdou ještě obnovit.")
            }
    }
}
