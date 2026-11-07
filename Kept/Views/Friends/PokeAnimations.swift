import BackgroundTasks
import SwiftUI

/// While the app is open, it checks every little while for news from friends; a poke that arrives
/// is shown at once with a small animation. In the background iOS wakes the app now and then to post
/// local notifications (real push comes with the Apple Developer account).
struct LiveSocial: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    private let notifications = NotificationsService.shared
    private static let interval: Duration = .seconds(45)

    func body(content: Content) -> some View {
        content
            .overlay {
                if let poke = notifications.incomingPoke {
                    PokeArrivedView(poke: poke) { notifications.incomingPoke = nil }
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: notifications.incomingPoke?.id)
            .task(id: scenePhase) {
                if scenePhase == .background { Self.scheduleRefresh() }
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await notifications.reload()
                    await FriendsService.shared.reload()
                    try? await Task.sleep(for: Self.interval)
                }
            }
    }

    /// Asks iOS to wake the app in about 20 minutes; iOS decides the real time.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: NotificationsService.refreshTaskID)
        request.earliestBeginDate = .now.addingTimeInterval(20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

/// "Petr tě šťouchl": a finger taps the screen from the side, rings spread from the tap, the phone buzzes.
struct PokeArrivedView: View {
    let poke: AppNotification
    let onDone: () -> Void
    @State private var tapped = false
    @State private var rings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea().onTapGesture(perform: onDone)
            VStack(spacing: 22) {
                ZStack {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(Theme.orange.opacity(0.6), lineWidth: 3)
                            .frame(width: 70, height: 70)
                            .scaleEffect(rings ? 2.6 + Double(index) * 0.5 : 0.4)
                            .opacity(rings ? 0 : 0.9)
                            .animation(reduceMotion ? nil : .easeOut(duration: 1.1).delay(Double(index) * 0.15), value: rings)
                    }
                    Image(systemName: "hand.point.left.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.orange)
                        .offset(x: tapped ? 18 : 160)
                        .rotationEffect(.degrees(tapped ? 0 : -18))
                }
                .frame(height: 200)
                VStack(spacing: 8) {
                    Text(poke.title)
                        .scaledFont(.title, weight: .heavy)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    if let detail = poke.detail {
                        Text("„\(detail)“")
                            .scaledFont(.heading)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                Button("JASNĚ, JDU NA TO") { onDone() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(28)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, Theme.screenPadding)
        }
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.55)) { tapped = true }
            try? await Task.sleep(for: .milliseconds(250))
            Haptics.warning()
            rings = true
            try? await Task.sleep(for: .milliseconds(180))
            Haptics.medium()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}

/// The send button of a poke: the finger jabs, the rings spread, the phone buzzes, then the sheet closes.
struct PokeSentBurst: View {
    let name: String
    @State private var jab = false
    @State private var rings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Theme.green.opacity(0.7), lineWidth: 3)
                        .frame(width: 60, height: 60)
                        .scaleEffect(rings ? 2.4 + Double(index) * 0.45 : 0.3)
                        .opacity(rings ? 0 : 1)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(Double(index) * 0.12), value: rings)
                }
                Image(systemName: "hand.point.right.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.green)
                    .offset(x: jab ? 0 : -90)
                    .scaleEffect(jab ? 1.15 : 0.9)
            }
            .frame(height: 170)
            Text("Šťouchnuto!")
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
            Text("\(name) to uvidí.")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.5)) { jab = true }
            try? await Task.sleep(for: .milliseconds(180))
            Haptics.success()
            rings = true
        }
    }
}
