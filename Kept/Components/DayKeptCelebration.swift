import SwiftUI

/// The moment the last task of the day is done: the whole screen says so for a second or two.
/// Tapping anywhere closes it early.
struct DayKeptCelebration: View {
    let done: Int
    let streak: Int
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.background.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.green.opacity(0.16))
                        .frame(width: 150, height: 150)
                        .scaleEffect(shown || reduceMotion ? 1 : 0.4)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(Theme.green)
                        .symbolEffect(.bounce, options: .nonRepeating, value: shown)
                }
                Text("DEN DODRŽEN")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.textPrimary)
                Text(done == 1 ? "Splnil jsi, co sis na dnes slíbil." : "Všech \(done) slibů na dnes je splněno.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                if streak > 1 {
                    Label("\(streak) dní v řadě", systemImage: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.orange)
                        .padding(.top, 4)
                }
            }
            .padding(32)
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 20)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .sensoryFeedback(.success, trigger: shown)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown = true }
            try? await Task.sleep(for: .seconds(2.4))
            onFinish()
        }
    }
}
