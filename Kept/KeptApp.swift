import SwiftUI
import SwiftData
import UserNotifications

@main
struct KeptApp: App {
    /// The intro plays once per cold start; this starts true every time the process launches.
    @State private var showsIntro = true
    @State private var isReady = false
    @AppStorage("introEnabled") private var introEnabled = true

    /// Nil when the video file is not part of the build — the app then simply starts without it.
    private static let introURL = Bundle.main.url(forResource: "Intro", withExtension: "mp4")

    init() {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        WidgetActions.complete = { await AppStore.completeFromWidget($0) }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(onReady: { isReady = true })
                if showsIntro, introEnabled, let url = Self.introURL {
                    IntroView(url: url, isReady: isReady) {
                        withAnimation(.easeOut(duration: 0.35)) { showsIntro = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .appAppearance()
            .environment(\.locale, .app)
        }
        .modelContainer(AppStore.container)
    }
}
