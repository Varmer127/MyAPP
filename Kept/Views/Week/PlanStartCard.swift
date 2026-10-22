import SwiftUI

/// The three ways to fill a week, side by side: quick planning, one task with all details,
/// and last week again. Plus a quiet way to start the draft over.
struct PlanStartCard: View {
    let previousWeek: Int
    let onQuick: () -> Void
    let onSingle: () -> Void
    let onCopy: () -> Void
    /// Nil hides the reset link, for example when there is nothing to clear.
    var onReset: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NAPLÁNUJ SI TÝDEN").labelStyle()
            HStack(spacing: 8) {
                tile("Rychlé plánování", detail: "Jedna aktivita na víc dní", symbol: "bolt.fill", action: onQuick)
                tile("Jeden úkol", detail: "Čas, délka i deadline", symbol: "plus", action: onSingle)
                tile("Jako minule", detail: "Týden \(previousWeek) znovu", symbol: "doc.on.doc", action: onCopy)
                    .flightFrame(PlanStartCard.copyTile)
            }
            if let onReset {
                Button(action: onReset) {
                    Label("Začít plán znovu", systemImage: "arrow.counterclockwise")
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 14)
    }

    static let copyTile = "copyTile"

    private func tile(_ title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol)
                    .scaledFont(.heading, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                Text(title)
                    .padding(.top, 12)
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .padding(10)
            .background(Theme.cardRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PressableTileStyle())
    }
}

/// A tile that dips slightly under the finger.
private struct PressableTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
