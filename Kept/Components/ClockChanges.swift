import SwiftUI
import UIKit

/// Calls `perform` when the day turns over, the clock is set, the time zone changes, or the app comes back to the front.
/// Things computed from "now" (today's date, the week, scheduled notifications) are not refreshed by data changes alone.
struct ClockChanges: ViewModifier {
    let perform: () -> Void
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in perform() }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in perform() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { perform() }
            }
    }
}

extension View {
    /// On iOS 26 the tab bar floats over the content. A soft fade at the bottom edge keeps the text that scrolls
    /// under it from showing through the glass and competing with the tab names.
    @ViewBuilder
    func softBottomEdge() -> some View {
        if #available(iOS 26, *) {
            self.scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            self
        }
    }
}
