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
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { isUnlocked = false }
                }
        } else {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textSecondary)
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if failed {
                    Text("Odemknutí se nepovedlo.")
                        .font(.system(size: 14))
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
