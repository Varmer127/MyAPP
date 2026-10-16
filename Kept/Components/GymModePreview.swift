import SwiftUI

/// A small picture of what the gym looks like in each mode, with what the mode can do.
/// Shown when choosing the mode in the guide and in the gym settings.
struct GymModePreview: View {
    let mode: GymMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Group {
                switch mode {
                case .simple: simple
                case .advanced: advanced
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(mode.features, id: \.self) { feature in
                    Label {
                        Text(feature).font(.system(size: 14)).foregroundStyle(Theme.textPrimary)
                    } icon: {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.green)
                    }
                }
            }
        }
        .card(padding: 14)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private var simple: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("PAUZA").labelStyle(Theme.orange)
                Text("01:12")
                    .font(.system(size: 40, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                ThinBar(value: 0.8, color: Theme.orange)
                    .frame(width: 140)
                Text("Cíl 01:30 · celkem 42:15")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 4) {
                ForEach(["Svaly", "Síla", "Vytrvalost"], id: \.self) { name in
                    Text(name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(name == "Svaly" ? Theme.cardRaised : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
            }
            .padding(3)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            Text("DALŠÍ SÉRIE")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Theme.orange)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
    }

    private var advanced: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Bench press").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.textPrimary)
                ForEach(Array(sampleSets.enumerated()), id: \.offset) { index, set in
                    HStack(spacing: 8) {
                        Text("\(index + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                        Text(set.text).font(.system(size: 13, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 4)
                        Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15))
                            .foregroundStyle(set.done ? Theme.green : Theme.textTertiary)
                    }
                    .padding(.horizontal, 8)
                    .frame(minHeight: 28)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                Text("Minule 80 kg × 8")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            MuscleMapView(intensity: [.chest: 1, .triceps: 0.45, .shoulders: 0.45], showsLabels: false)
                .frame(width: 120, height: 130)
        }
    }

    private var sampleSets: [(text: String, done: Bool)] {
        [("80 kg × 8", true), ("80 kg × 8", true), ("82,5 kg × 6", false)]
    }
}
