import SwiftUI
import SwiftData
import UserNotifications

@main
struct KeptApp: App {
    /// The intro plays once per cold start; this starts true every time the process launches.
    @State private var showsIntro = true
    @State private var isReady = false
    init() {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        WidgetActions.complete = { await AppStore.completeFromWidget($0) }
        WidgetActions.gymRest = { await GymActivityManager.toggleRest(start: $0) }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(onReady: { isReady = true })
                if showsIntro {
                    LaunchAnimationView {
                        withAnimation(.easeOut(duration: 0.35)) { showsIntro = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .appAppearance()
            .environment(\.locale, .app)
            .modifier(FriendLinkHandler())
            .task { await AccountService.shared.restore() }
        }
        .modelContainer(AppStore.container)
    }
}
