import SwiftUI
import UIKit

/// Shows the app's language and opens Kept in the iPhone settings, where iOS lets each app have its own language.
/// The app then restarts in the chosen language by itself.
struct LanguageRow: View {
    var body: some View {
        Button {
            Haptics.light()
            Self.openSettings()
        } label: {
            HStack {
                Label("Jazyk", systemImage: "globe")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(AppLanguage.current == .en ? "English" : "Čeština")
                    .foregroundStyle(Theme.textSecondary)
                Image(systemName: "arrow.up.forward.app")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .accessibilityHint("Otevře nastavení iPhonu, kde se jazyk aplikace mění")
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
