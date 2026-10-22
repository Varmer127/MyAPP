import SwiftUI
import SwiftData

extension OnboardingView {
    func option(_ title: String, _ subtitle: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        choice(isOn, action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).scaledFont(.body, weight: .bold)
                if let subtitle {
                    Text(subtitle).scaledFont(.caption).opacity(isOn ? 0.75 : 1)
                        .foregroundStyle(isOn ? Theme.onPrimary : Theme.textSecondary)
                }
            }
        }
    }

    func note(_ text: String) -> some View {
        Text(text)
            .scaledFont(.caption)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
                Text(subtitle).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .tint(Theme.green)
        .card()
    }

    func stepper(_ value: String, caption: String? = nil, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            roundButton("minus", label: "Méně", action: minus)
            Spacer()
            VStack(spacing: 2) {
                Text(value)
                    .scaledFont(.hero, weight: .heavy)
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText())
                if let caption { Text(caption).labelStyle() }
            }
            Spacer()
            roundButton("plus", label: "Více", action: plus)
        }
        .card()
    }

    func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .scaledFont(.heading, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48, height: 48)
                .background(Theme.cardRaised)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    func chip(_ title: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(isOn ? Theme.textPrimary : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isOn ? Theme.textPrimary : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }

    func compactStepper(_ value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            smallRound("minus", label: "Dřív", action: minus)
            Text(value)
                .scaledFont(.heading, weight: .heavy)
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 62)
            smallRound("plus", label: "Později", action: plus)
        }
    }

    func smallRound(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.cardRaised)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
