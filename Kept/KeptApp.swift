import SwiftUI
import SwiftData
import UserNotifications

@main
struct KeptApp: App {
    /// The intro plays once per cold start; this starts true every time the process launches.
    @State private var showsIntro = true
    @State private var isReady = false
    /// Off by default (new key, so it is off on existing installs too). The video goes before release.
    @AppStorage("introVideoEnabled") private var introEnabled = false

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
                } else if showsIntro {
                    LaunchAnimationView {
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
