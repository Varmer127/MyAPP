import SwiftUI

struct SectionLabel: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text.uppercased())
            .labelStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Badge: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

/// Number over label, used in rows of three under the hero score.
struct MetricTile: View {
    /// What a tile says when there is nothing to measure yet; also what the statistics say.
    static let noData = "po prvním týdnu"

    let value: String
    let label: String
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: value == Self.noData ? 15 : 26, weight: value == Self.noData ? .semibold : .bold))
                .foregroundStyle(value == Self.noData ? Theme.textTertiary : color)
                .frame(minHeight: 32, alignment: .leading)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.5), value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .card(padding: 14)
    }
}

/// Thin horizontal performance bar with label and percentage.
struct PerformanceBar: View {
    let label: String
    let value: Double?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label.uppercased()).labelStyle()
                Spacer()
                // No data yet is not a failure, so it reads as a promise of what comes.
                if value == nil {
                    Text("po prvním týdnu")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(value.percentText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            ThinBar(value: value ?? 0, color: Theme.performanceColor(value))
        }
    }
}

struct ThinBar: View {
    let value: Double
    var color: Color = Theme.textPrimary

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardRaised)
                Capsule().fill(color)
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.4), value: value)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.textPrimary
    var textColor: Color = Theme.onPrimary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 6)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.3)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var textColor: Color = Theme.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .padding(.horizontal, 6)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
