import LocalAuthentication
import SwiftUI

/// Hides the diary behind Face ID (or the passcode) when the lock is switched on.
/// It locks again whenever the app goes to the background.
struct DiaryLock: ViewModifier {
    let isEnabled: Bool
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
                Text("Deník je zamčený")
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
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Odemknout deník") { success, _ in
            DispatchQueue.main.async {
                isUnlocked = success
                failed = !success
            }
        }
    }
}

extension View {
    func diaryLock(_ isEnabled: Bool) -> some View { modifier(DiaryLock(isEnabled: isEnabled)) }
}
