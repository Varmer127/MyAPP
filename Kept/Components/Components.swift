import SwiftUI
import Charts

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
            .scaledFont(.caption, weight: .bold)
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
                .scaledFont(value == Self.noData ? 15 : 26, weight: value == Self.noData ? .semibold : .bold)
                .foregroundStyle(value == Self.noData ? Theme.textTertiary : color)
                .frame(minHeight: 32, alignment: .leading)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.5), value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}

/// Tiles side by side, or one under another when the text size is so large that three would not fit.
struct TileRow<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize >= .accessibility1 {
            VStack(spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

/// Thin horizontal performance bar with label and percentage.
struct PerformanceBar: View {
    let label: String
    let value: Double?
    /// The value in the weeks before, oldest first. With enough of them the bar becomes a small curve of its own development.
    var series: [Double?] = []

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                // No data yet is not a failure, so it reads as a promise of what comes.
                if value == nil {
                    Text("po prvním týdnu")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    Text(value.percentText)
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            if series.compactMap({ $0 }).count >= 3 {
                Sparkline(values: series, color: Theme.performanceColor(value))
            } else {
                ThinBar(value: value ?? 0, color: Theme.performanceColor(value))
            }
        }
    }
}

/// A small line of how a share (0...1) developed over the last weeks, with the latest point marked.
struct Sparkline: View {
    let values: [Double?]
    var color: Color = Theme.textPrimary

    var body: some View {
        let points = values.enumerated().compactMap { index, value in value.map { (index, $0) } }
        Chart {
            ForEach(points, id: \.0) { point in
                LineMark(x: .value("Týden", point.0), y: .value("Hodnota", point.1))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(color)
            }
            if let last = points.last {
                PointMark(x: .value("Týden", last.0), y: .value("Hodnota", last.1))
                    .symbolSize(40)
                    .foregroundStyle(color)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...1)
        .chartXScale(domain: 0...max(values.count - 1, 1))
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vývoj za poslední týdny")
        .accessibilityValue(points.last.map { "Naposledy \(Int(($0.1 * 100).rounded())) %" } ?? "")
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
            .scaledFont(.body, weight: .bold)
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
            .scaledFont(.body, weight: .bold)
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
