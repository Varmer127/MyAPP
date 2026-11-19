import SwiftUI

/// The app's language, switched right here in Settings; everything is drawn again in it at once.
struct LanguageRow: View {
    var body: some View {
        Picker(selection: Binding(get: { AppLanguage.current }, set: { language in
            Haptics.light()
            LanguageSwitch.shared.select(language, reopeningSettings: true)
        })) {
            ForEach(AppLanguage.allCases) { Text(verbatim: $0.title).tag($0) }
        } label: {
            Label("Jazyk", systemImage: "globe")
        }
        .tint(Theme.textPrimary)
    }
}
