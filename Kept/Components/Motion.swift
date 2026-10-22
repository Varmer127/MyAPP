import SwiftUI
import UIKit

/// Haptics as a small language, one feel per meaning, so the hand learns what happened without looking:
/// - `light`: a touch, a choice, a switch.
/// - `medium`: something is done (a task, a set).
/// - `success`: keeping your word (the day is kept, a badge is earned).
/// - `heavy`: the seal.
/// - `warning`: a promise is broken or a limit is hit. Never a hard knock: the app is a coach, not a judge.
enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// The circle with a check that draws itself, as in the welcome animation. A task that was just completed
/// draws it; one that was done earlier simply shows it.
struct DrawnCheck: View {
    let isRecent: Bool
    var color: Color = Theme.green
    var size: CGFloat = 22
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().fill(color).scaleEffect(progress > 0 || !isRecent ? 1 : 0.4)
            CheckStroke()
                .trim(from: 0, to: isRecent ? progress : 1)
                .stroke(Theme.onPrimary, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.5, height: size * 0.4)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard isRecent, !reduceMotion else { progress = 1; return }
            withAnimation(.easeOut(duration: 0.55)) { progress = 1 }
        }
        .accessibilityHidden(true)
    }
}

/// A few sparks that fly out when `trigger` changes, for the flame that just grew.
struct SparkBurst: View {
    let trigger: Int
    @State private var progress: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) / 6 * 2 * .pi - .pi / 2
                Image(systemName: "sparkle")
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(Theme.orange)
                    .offset(x: cos(angle) * 30 * progress, y: sin(angle) * 30 * progress)
                    .scaleEffect(1 - progress * 0.5)
                    .opacity(progress >= 1 ? 0 : 1 - progress)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            guard !reduceMotion else { return }
            progress = 0
            withAnimation(.easeOut(duration: 0.7)) { progress = 1 }
        }
    }
}

/// The seal dropping onto a plan: the moment a week becomes a promise.
struct SealStamp: View {
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var ring = false
    @State private var textShown = false

    var body: some View {
        ZStack {
            Theme.background.opacity(landed ? 0.9 : 0).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(Theme.green.opacity(0.5), lineWidth: 3)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ring ? 1.5 : 0.9)
                        .opacity(ring ? 0 : 0.9)
                    Circle()
                        .fill(Theme.textPrimary)
                        .frame(width: 140, height: 140)
                        .shadow(color: Theme.green.opacity(landed ? 0.45 : 0), radius: 24)
                    Circle()
                        .strokeBorder(Theme.onPrimary.opacity(0.35), lineWidth: 2)
                        .frame(width: 122, height: 122)
                    CheckStroke()
                        .trim(from: 0, to: landed ? 1 : 0)
                        .stroke(Theme.onPrimary, style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                        .frame(width: 62, height: 48)
                        .offset(y: -3)
                    Capsule()
                        .fill(Theme.green)
                        .frame(width: landed ? 54 : 0, height: 6)
                        .offset(y: 38)
                }
                .scaleEffect(landed || reduceMotion ? 1 : 2.4)
                .rotationEffect(.degrees(landed || reduceMotion ? 0 : -14))
                .opacity(landed || reduceMotion ? 1 : 0)
                VStack(spacing: 6) {
                    Text("ZAPEČETĚNO")
                        .scaledFont(.title, weight: .heavy)
                        .tracking(2)
                        .foregroundStyle(Theme.textPrimary)
                    Text("Tohle je teď tvůj slib. Dodrž ho.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .opacity(textShown || reduceMotion ? 1 : 0)
                .offset(y: textShown || reduceMotion ? 0 : 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Týden je zapečetěný")
        .task {
            if reduceMotion {
                landed = true; ring = true; textShown = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) { landed = true }
                try? await Task.sleep(for: .milliseconds(180))
                Haptics.heavy()
                withAnimation(.easeOut(duration: 0.7)) { ring = true }
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.easeOut(duration: 0.4)) { textShown = true }
            }
            try? await Task.sleep(for: .seconds(2.2))
            onFinish()
        }
    }
}


/// A band of light that sweeps once across a card, for the moment something is completed.
struct SweepHighlight: View {
    let trigger: Bool
    var cornerRadius: CGFloat = Theme.radius
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: CGFloat = -0.4

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, Theme.green.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.4)
                .offset(x: proxy.size.width * position)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, on in
            guard on, !reduceMotion else { return }
            position = -0.4
            withAnimation(.easeInOut(duration: 0.9)) { position = 1.0 }
        }
    }
}
