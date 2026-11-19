import Foundation
import SwiftUI
import WidgetKit

/// Switching the app's language from inside the app, without leaving it for the iPhone settings.
/// The texts are looked up in the chosen language from then on and the screens are drawn again.
@MainActor
@Observable
final class LanguageSwitch {
    static let shared = LanguageSwitch()

    /// Bumped on every switch; the root view uses it to draw everything again in the new language.
    private(set) var revision = 0

    /// Set when the switch came from Settings, so the redrawn app opens on Settings again, not on Today.
    @ObservationIgnored private var reopensSettings = false

    private init() {}

    /// Read once by the redrawn root view.
    func takeReopensSettings() -> Bool {
        defer { reopensSettings = false }
        return reopensSettings
    }

    /// Called once at launch, before anything is shown.
    static func installAtLaunch() {
        KeptLanguage.install(code: AppLanguage.current.rawValue)
        ActivityNames.follow(AppLanguage.current, in: AppStore.container.mainContext)
    }

    func select(_ language: AppLanguage, reopeningSettings: Bool = false) {
        guard language != AppLanguage.current else { return }
        reopensSettings = reopeningSettings
        KeptLanguage.save(language.rawValue)
        KeptLanguage.use(language.rawValue)
        // Built-in activity names stored in tasks follow, so notifications and widgets say them in the new language.
        ActivityNames.follow(language, in: AppStore.container.mainContext)
        revision += 1
        WidgetCenter.shared.reloadAllTimelines()
        // Scheduled notifications were written in the old language.
        Task { await NotificationManager.reschedule(context: AppStore.container.mainContext) }
    }
}
