import SwiftUI
import WidgetKit

@main
struct KeptWidgetsBundle: WidgetBundle {
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
