import SwiftUI

/// The streak on Today: a small flame and the number of days, next to the bell. While a streak is alive the flame burns,
/// flickering on its own; on the evening the streak would break it flickers faster and dims, like it is running out.
/// Without a streak it is a quiet grey outline.
struct StreakFlame: View {
    let streak: Int
    let atRisk: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLit: Bool { streak > 0 }

    var body: some View {
        HStack(spacing: 4) {
            icon
                .frame(width: 17, height: 21)
            Text("\(streak)")
                .scaledFont(.body, weight: .heavy)
                .monospacedDigit()
                .foregroundStyle(isLit ? Theme.textPrimary : Theme.textTertiary)
                .contentTransition(.numericText())
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var icon: some View {
        if isLit, !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                burning(at: context.date.timeIntervalSinceReferenceDate)
            }
        } else if isLit {
            flameShape()
        } else {
            Image(systemName: "flame")
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textTertiary)
        }
    }

    /// Three sine waves of different speeds make the flicker irregular, the way a real flame never repeats.
    private func burning(at time: TimeInterval) -> some View {
        let speed = atRisk ? 10.0 : 5.5
        let flicker = sin(time * speed) * 0.5 + sin(time * speed * 1.7 + 1.3) * 0.3 + sin(time * speed * 2.9 + 0.4) * 0.2
        let core = sin(time * speed * 1.3 + 2) * 0.5 + sin(time * speed * 2.3) * 0.5
        // A streak about to break gutters: now and then it sinks and fades for a moment.
        let gutter = atRisk ? max(0, sin(time * 1.6)) * 0.25 : 0
        return ZStack(alignment: .bottom) {
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LinearGradient(colors: [Theme.flameTip, Theme.flameBody], startPoint: .top, endPoint: .bottom))
                .scaleEffect(x: 1 - flicker * 0.05, y: 1 + flicker * 0.09 - gutter, anchor: .bottom)
                .rotationEffect(.degrees(flicker * 5), anchor: .bottom)
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 9, height: 11)
                .foregroundStyle(Theme.flameCore)
                .scaleEffect(x: 1 + core * 0.06, y: 1 + core * 0.16 - gutter, anchor: .bottom)
                .offset(x: flicker * 0.6, y: -1.5)
        }
        .opacity(1 - gutter)
        .shadow(color: Theme.flameBody.opacity(0.45 + flicker * 0.15), radius: 5 + flicker * 1.5)
    }

    private func flameShape() -> some View {
        ZStack(alignment: .bottom) {
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LinearGradient(colors: [Theme.flameTip, Theme.flameBody], startPoint: .top, endPoint: .bottom))
            Image(systemName: "flame.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 9, height: 11)
                .foregroundStyle(Theme.flameCore)
                .offset(y: -1.5)
        }
    }
}
