import SwiftUI

struct PointsGain: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
    /// Shown instead of points when the task earned none (a week not sent yet).
    var text: String? = nil
}

/// "+100 bodů" that pops up, drifts upwards and fades out on its own. Never needs to be dismissed.
/// With `onSpend` it stays a little longer and touching it opens the shop.
struct PointsGainToast: View {
    let amount: Int
    var text: String? = nil
    var onSpend: (() -> Void)? = nil
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var leaving = false

    private static let visibleFor: Duration = .milliseconds(1100)
    /// Long enough to reach for the "Utratit" part.
    private static let visibleWithSpendFor: Duration = .milliseconds(2600)

    private var spends: Bool { onSpend != nil && text == nil }

    var body: some View {
        Button {
            onSpend?()
            onFinish()
        } label: {
            HStack(spacing: 10) {
                Label(text ?? "+\(amount.formatted(.number.locale(.app))) BODŮ", systemImage: text == nil ? "sparkles" : "checkmark")
                if spends {
                    Rectangle().fill(Theme.onPrimary.opacity(0.3)).frame(width: 1, height: 18)
                    HStack(spacing: 3) {
                        Text("UTRATIT")
                        Image(systemName: "chevron.right")
                    }
                    .scaledFont(.caption, weight: .heavy)
                }
            }
            .scaledFont(.body, weight: .heavy)
            .tracking(0.8)
            .foregroundStyle(Theme.onPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Theme.green)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!spends)
        .accessibilityHint(spends ? "Otevře obchod s odměnami" : "")
            .shadow(color: Theme.green.opacity(0.35), radius: 14, y: 4)
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.6))
            .offset(y: reduceMotion ? 0 : (leaving ? -70 : (shown ? 0 : 24)))
            .opacity(leaving ? 0 : (shown ? 1 : 0))
            .task {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true }
                try? await Task.sleep(for: spends ? Self.visibleWithSpendFor : Self.visibleFor)
                withAnimation(.easeIn(duration: 0.45)) { leaving = true }
                try? await Task.sleep(for: .milliseconds(450))
                onFinish()
            }
    }
}
