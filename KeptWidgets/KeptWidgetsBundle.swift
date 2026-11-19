import SwiftUI
import WidgetKit

@main
struct KeptWidgetsBundle: WidgetBundle {
    /// The widgets speak the language chosen in the app.
    init() {
        KeptLanguage.install(code: nil)
    }

    var body: some Widget {
        TodayWidget()
        NextTaskWidget()
        WeekWidget()
        StreakWidget()
        ScoreWidget()
        GymWidget()
        FocusLiveActivity()
        GymLiveActivity()
        SealLiveActivity()
    }
}
