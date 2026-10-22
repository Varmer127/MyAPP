import SwiftUI
import Charts

/// Weekly muscle map, volume per muscle, records and a training calendar for the Gym screen.
struct GymInsights: View {
    let logs: [ExerciseLog]
    let workouts: [TaskItem]

    @State private var weekOffset = 0

    private static let calendarWeeks = 12

    private var weekStart: Date { Date.now.weekStart.addingDays(-7 * weekOffset) }

    /// How many weeks back the oldest logged workout is: going further back would only show empty weeks.
    private var maxOffset: Int {
        guard let oldest = logs.map({ $0.date.weekStart }).min() else { return 0 }
        return max(0, (Calendar.app.dateComponents([.day], from: oldest, to: Date.now.weekStart).day ?? 0) / 7)
    }

    private func moveWeek(by step: Int) {
        let target = min(max(weekOffset + step, 0), maxOffset)
        guard target != weekOffset else { return }
        Haptics.light()
        withAnimation(.easeInOut(duration: 0.25)) { weekOffset = target }
    }

    /// Working sets per muscle in the shown week; a secondary muscle counts half.
    private var setsPerMuscle: [Muscle: Double] {
        var result: [Muscle: Double] = [:]
        // Only finished workouts: a session still in progress or abandoned does not count yet.
        for log in logs where log.date.weekStart == weekStart && log.task?.isDone == true {
            guard let exercise = ExerciseCatalog.named(log.name) else { continue }
            let sets = Double(log.workingSets.count)
            for muscle in exercise.primary { result[muscle, default: 0] += sets }
            for muscle in exercise.secondary where !exercise.primary.contains(muscle) { result[muscle, default: 0] += sets / 2 }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            muscleMap
            records
            calendar
        }
    }

    // MARK: Muscle map

    private var muscleMap: some View {
        let sets = setsPerMuscle
        let top = sets.values.max() ?? 0
        return VStack(spacing: 10) {
            HStack(spacing: 4) {
                SectionLabel(text: weekOffset == 0 ? "Svaly tento týden"
                             : "Týden \(weekStart.weekNumber) · \(weekStart.dayMonthText) – \(weekStart.addingDays(6).dayMonthText)")
                Spacer(minLength: 6)
                if weekOffset > 0 {
                    // One tap from any week back to the present.
                    Button { moveWeek(by: -weekOffset) } label: {
                        Text("TEĎ")
                            .scaledFont(.caption, weight: .heavy)
                            .foregroundStyle(Theme.onPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Theme.textPrimary)
                            .clipShape(Capsule())
                            // The capsule stays small; the area that can be tapped is the 44 points iOS asks for.
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Zpět na tento týden")
                }
                Button { moveWeek(by: 1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 32) }
                    .disabled(weekOffset >= maxOffset)
                    .accessibilityLabel("Předchozí týden")
                Button { moveWeek(by: -1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 32) }
                    .disabled(weekOffset == 0)
                    .accessibilityLabel("Další týden")
            }
            .foregroundStyle(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 14) {
                MuscleMapView(intensity: top > 0 ? sets.mapValues { $0 / top } : [:])
                    .frame(height: 220)
                    .contentShape(Rectangle())
                    // Swiping the map moves between weeks, like the arrows.
                    .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { drag in
                        guard abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                        moveWeek(by: drag.translation.width > 0 ? 1 : -1)
                    })
                if sets.isEmpty {
                    Text(weekOffset == 0 ? "Tento týden zatím žádný zapsaný trénink. Partie se rozsvítí podle odcvičených sérií."
                                         : "V tomto týdnu žádný zapsaný trénink.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Chart(sets.sorted { $0.value > $1.value }, id: \.key) { muscle, value in
                        BarMark(x: .value("Série", value), y: .value("Partie", muscle.title))
                            .foregroundStyle(Theme.green)
                            .cornerRadius(3)
                            .annotation(position: .trailing) {
                                Text(value.formatted(.number.precision(.fractionLength(0...1)).locale(.app)))
                                    .scaledFont(.caption, weight: .semibold)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks { AxisValueLabel().foregroundStyle(Theme.textSecondary) }
                    }
                    .frame(height: CGFloat(sets.count) * 26)
                    Text("Pracovní série za týden. Pomocné svaly se počítají napůl, rozcvičky vůbec.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .card()
        }
    }

    // MARK: Records

    private var records: some View {
        let best = Dictionary(grouping: logs.filter { $0.task?.isDone == true }, by: \.name).compactMap { name, logs -> (String, ExerciseLog)? in
            guard let top = logs.max(by: { $0.bestEstimatedMax < $1.bestEstimatedMax }), top.bestEstimatedMax > 0 else { return nil }
            return (name, top)
        }
        .sorted { $0.1.bestEstimatedMax > $1.1.bestEstimatedMax }
        return VStack(spacing: 10) {
            SectionLabel(text: "Osobní rekordy")
            if best.isEmpty {
                Text("Rekordy se objeví po prvních zapsaných sériích s váhou.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(best.prefix(8).enumerated()), id: \.element.0) { index, item in
                        if index > 0 { Divider().overlay(Theme.border) }
                        let set = item.1.workingSets.max { ExerciseLog.estimatedMax(weight: $0.weight, reps: $0.reps) < ExerciseLog.estimatedMax(weight: $1.weight, reps: $1.reps) }
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(index == 0 ? Theme.orange : Theme.textTertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.0).scaledFont(.body, weight: .semibold).foregroundStyle(Theme.textPrimary)
                                Text(item.1.date.dayMonthText + (set.map { " · \($0.weight.kilogramText) × \($0.reps)" } ?? ""))
                                    .scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.1.bestEstimatedMax.kilogramText).scaledFont(.body, weight: .bold).foregroundStyle(Theme.textPrimary)
                                Text("odhad maxima").scaledFont(.caption).foregroundStyle(Theme.textTertiary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    // MARK: Calendar

    private var calendar: some View {
        let start = Date.now.weekStart.addingDays(-7 * (Self.calendarWeeks - 1))
        let trained = Set(workouts.filter(\.isDone).map { $0.scheduledDate.startOfDay })
        let perWeek = (0..<Self.calendarWeeks).map { week in
            (0..<7).filter { trained.contains(start.addingDays(week * 7 + $0)) }.count
        }
        let average = Double(perWeek.dropLast().reduce(0, +)) / Double(max(Self.calendarWeeks - 1, 1))
        return VStack(spacing: 10) {
            SectionLabel(text: "Tréninky za \(Self.calendarWeeks) týdnů")
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(0..<Self.calendarWeeks, id: \.self) { week in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { day in
                                let date = start.addingDays(week * 7 + day)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(trained.contains(date) ? Theme.green : (date > .now ? Color.clear : Theme.cardRaised))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                Text("Průměrně \(average.formatted(.number.precision(.fractionLength(0...1)).locale(.app)))× týdně za posledních \(Self.calendarWeeks - 1) dokončených týdnů.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
        }
    }
}
