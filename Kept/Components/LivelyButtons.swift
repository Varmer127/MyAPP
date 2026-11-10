import SwiftUI

// Buttons that answer the finger: they give a little under the press, spring back, buzz, and show what happens
// (working, done, failed) instead of just sitting there. Use these for every action in Kept.

/// The springy press shared by all of Kept's button styles.
struct PressBounce: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1)
            .brightness(isPressed ? -0.04 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55), value: isPressed)
    }
}

/// A compact capsule for actions inside rows: accept, ask, cancel, poke.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, positive, destructive }
    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    private var background: Color {
        switch kind {
        case .primary: Theme.textPrimary
        case .secondary: Theme.cardRaised
        case .positive: Theme.green
        case .destructive: Theme.red.opacity(0.15)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.onPrimary
        case .secondary: Theme.textPrimary
        case .positive: Color(hex: 0x000000)
        case .destructive: Theme.red
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(.caption, weight: .bold)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(kind == .secondary ? Theme.border : .clear, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .modifier(PressBounce(isPressed: configuration.isPressed))
    }
}

/// Runs an async action and shows how it goes: a spinner while it works, a bouncing check with a buzz when it
/// is done, a shake when it fails. With `doneTitle` the button stays in the done state, otherwise it comes back.
struct ActionButton: View {
    enum Look { case big(PrimaryButtonStyle), bigSecondary(SecondaryButtonStyle), pill(PillButtonStyle.Kind) }

    let title: LocalizedStringKey
    var symbol: String?
    var doneTitle: LocalizedStringKey?
    var look: Look = .big(PrimaryButtonStyle())
    let action: () async throws -> Void

    private enum Phase { case idle, working, done, failed }
    @State private var phase: Phase = .idle
    @State private var shakes = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        styled(Button(action: run) { label })
            .disabled(phase == .working || (phase == .done && doneTitle != nil))
            .modifier(ShakeEffect(animatableData: CGFloat(shakes)))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: phase)
    }

    @ViewBuilder
    private var label: some View {
        HStack(spacing: 6) {
            switch phase {
            case .working:
                ProgressView().controlSize(.small).tint(tint)
            case .done:
                Image(systemName: "checkmark")
                    .fontWeight(.heavy)
                    .symbolEffect(.bounce, value: phase == .done)
                    .transition(.scale.combined(with: .opacity))
            case .idle, .failed:
                if let symbol { Image(systemName: symbol).transition(.scale.combined(with: .opacity)) }
            }
            Text(phase == .done ? (doneTitle ?? title) : title)
                .contentTransition(.opacity)
        }
    }

    private var tint: Color {
        switch look {
        case .big(let style): style.textColor
        case .bigSecondary(let style): style.textColor
        case .pill(let kind): kind == .primary ? Theme.onPrimary : Theme.textPrimary
        }
    }

    @ViewBuilder
    private func styled(_ button: Button<some View>) -> some View {
        switch look {
        case .big(let style): button.buttonStyle(style)
        case .bigSecondary(let style): button.buttonStyle(style)
        case .pill(let kind): button.buttonStyle(PillButtonStyle(kind: kind))
        }
    }

    private func run() {
        guard phase != .working else { return }
        Haptics.light()
        phase = .working
        Task {
            do {
                try await action()
                Haptics.success()
                phase = .done
                if doneTitle == nil {
                    try? await Task.sleep(for: .seconds(1.2))
                    phase = .idle
                }
            } catch {
                Haptics.warning()
                phase = .failed
                if !reduceMotion { withAnimation(.default) { shakes += 1 } }
                try? await Task.sleep(for: .seconds(0.6))
                phase = .idle
            }
        }
    }
}

/// A short side-to-side shake for something that did not work.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0))
    }
}
