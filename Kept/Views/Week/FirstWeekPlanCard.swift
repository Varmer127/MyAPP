import SwiftUI

/// Greets a new user on the Week tab right after the guide: "let's plan your first week". When Kept was started
/// mid-week, it shows which days are left, says the days gone by do not count and names the smaller minimum.
struct FirstWeekPlanCard: View {
    let weekStart: Date
    /// Set when the first week started after its Monday.
    let isShortened: Bool
    let minimum: Int
    let usualMinimum: Int
    let onPlan: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownDays = 0

    private var days: [Date] { (0..<7).map { weekStart.addingDays($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TVŮJ PRVNÍ TÝDEN").labelStyle(Theme.green)
            Text("Pojďme naplánovat tvůj první týden.")
                .scaledFont(.title, weight: .heavy)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            dayStrip
            VStack(alignment: .leading, spacing: 6) {
                Text(isShortened
                     ? "Začínáš uprostřed týdne a to je úplně v pořádku. Naplánuj jen dny, které zbývají. Ty, co už uplynuly, se nepočítají."
                     : "Celý týden je před tebou. Rozlož si aktivity do dnů, zkontroluj plán a odešli plánovač. Tím se z plánu stane slib.")
                if isShortened, minimum > 0, minimum < usualMinimum {
                    Text("Minimum aktivit je pro tenhle týden menší: \(minimum) místo \(usualMinimum).")
                }
            }
            .scaledFont(.body)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            Button(isShortened ? "NAPLÁNOVAT ZBYTEK TÝDNE" : "NAPLÁNOVAT PRVNÍ TÝDEN") {
                Haptics.light()
                onPlan()
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.green, textColor: Theme.onPrimary))
        }
        .card(padding: 16)
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.green.opacity(0.5), lineWidth: 1))
        .task {
            // The days light up one after another, so the eye goes to the ones that are left.
            guard !reduceMotion else { shownDays = days.count; return }
            for index in days.indices {
                try? await Task.sleep(for: .milliseconds(70))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { shownDays = index + 1 }
            }
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isPast = day.endOfDay <= Date.now
                let isToday = day.isSameDay(as: .now)
                VStack(spacing: 2) {
                    Text(day.weekdayShortText.capitalizedFirst)
                        .scaledFont(.caption, weight: .bold)
                    Text("\(Calendar.app.component(.day, from: day))")
                        .scaledFont(.caption)
                }
                .foregroundStyle(isPast ? Theme.textTertiary : (isToday ? Theme.onPrimary : Theme.textPrimary))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isPast ? Color.clear : (isToday ? Theme.green : Theme.cardRaised))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isPast ? Theme.border : Color.clear, lineWidth: 1))
                .strikethrough(isPast)
                .scaleEffect(index < shownDays ? 1 : 0.6)
                .opacity(index < shownDays ? (isPast ? 0.55 : 1) : 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isPast ? "\(day.longDayText), uplynulo" : day.longDayText)
            }
        }
    }
}
