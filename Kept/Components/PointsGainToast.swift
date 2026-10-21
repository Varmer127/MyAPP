import SwiftUI

struct PointsGain: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
    /// Shown instead of points when the task earned none (a week not sent yet).
    var text: String? = nil
}

/// "+100 bodů" that pops up, drifts upwards and fades out on its own. Never needs to be dismissed.
struct PointsGainToast: View {
    let amount: Int
    var text: String? = nil
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var leaving = false

    private static let visibleFor: Duration = .milliseconds(1100)

    var body: some View {
        Label(text ?? "+\(amount.formatted(.number.locale(.app))) BODŮ", systemImage: text == nil ? "sparkles" : "checkmark")
            .font(.system(size: 15, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(Theme.onPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.green)
            .clipShape(Capsule())
            .shadow(color: Theme.green.opacity(0.35), radius: 14, y: 4)
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.6))
            .offset(y: reduceMotion ? 0 : (leaving ? -70 : (shown ? 0 : 24)))
            .opacity(leaving ? 0 : (shown ? 1 : 0))
            .task {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true }
                try? await Task.sleep(for: Self.visibleFor)
                withAnimation(.easeIn(duration: 0.45)) { leaving = true }
                try? await Task.sleep(for: .milliseconds(450))
                onFinish()
            }
    }
}
