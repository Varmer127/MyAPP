import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, week, stats, settings
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .today

    var body: some View {
        TabView(selection: $tab) {
            TodayView(openWeek: { tab = .week })
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)
            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(AppTab.week)
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
                .tag(AppTab.stats)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(.white)
        .task {
            _ = UserSettings.current(in: context)
        }
    }
}

/// Identifiable request to open the task editor for a new or existing task.
struct EditorRequest: Identifiable {
    let id = UUID()
    var task: TaskItem?
    var date: Date = .now
}

struct ExcuseRequest: Identifiable {
    let id = UUID()
    let task: TaskItem
    let kind: FailureKind
}
