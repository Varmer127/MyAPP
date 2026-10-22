import LocalAuthentication
import SwiftUI

/// Hides a screen (the diary, or the whole app) behind Face ID or the passcode when the lock is switched on.
/// It locks again whenever the app goes to the background.
struct FaceIDLock: ViewModifier {
    let isEnabled: Bool
    let title: String
    let reason: String
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var failed = false

    func body(content: Content) -> some View {
        if !isEnabled || isUnlocked {
            content
                .privacyShield(isEnabled)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { isUnlocked = false }
                }
        } else {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "lock.fill")
                    .scaledFont(40)
                    .foregroundStyle(Theme.textSecondary)
                Text(title)
                    .scaledFont(.title, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                if failed {
                    Text("Odemknutí se nepovedlo.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.orange)
                }
                Button("ODEMKNOUT", action: unlock)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 260)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .screenBackground()
            .task { unlock() }
        }
    }

    private func unlock() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                isUnlocked = success
                failed = !success
            }
        }
    }
}

extension View {
    func diaryLock(_ isEnabled: Bool) -> some View {
        modifier(FaceIDLock(isEnabled: isEnabled, title: "Deník je zamčený", reason: "Odemknout deník"))
    }

    func appLock(_ isEnabled: Bool) -> some View {
        modifier(FaceIDLock(isEnabled: isEnabled, title: "Kept je zamčený", reason: "Odemknout Kept"))
    }
}

/// Covers a screen while the app is not in front, so the picture iOS takes for the app switcher shows nothing private.
/// iOS takes that picture when the app becomes inactive, before it goes to the background.
struct PrivacyShield: ViewModifier {
    var isEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay {
            if isEnabled && scenePhase != .active {
                ZStack {
                    Theme.background
                    Image(systemName: "lock.fill")
                        .scaledFont(34)
                        .foregroundStyle(Theme.textTertiary)
                }
                .ignoresSafeArea()
            }
        }
    }
}

extension View {
    func privacyShield(_ isEnabled: Bool = true) -> some View {
        modifier(PrivacyShield(isEnabled: isEnabled))
    }
}
