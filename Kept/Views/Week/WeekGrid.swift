import SwiftUI

/// The week at a glance: seven columns with a dot for every promise (green kept, red broken, grey still waiting).
/// Touching a day opens it under the grid.
struct WeekGrid: View {
    let days: [Date]
    let tasks: (Date) -> [TaskItem]
    let selected: Date
    let onSelect: (Date) -> Void

    private static let maxDots = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                cell(day)
                    .flightFrame(Self.flightKey(index))
            }
        }
    }

    static func flightKey(_ index: Int) -> String { "weekGridDay\(index)" }

    private func cell(_ day: Date) -> some View {
        let items = tasks(day)
        let isSelected = day.isSameDay(as: selected)
        let isToday = day.isSameDay(as: .now)
        let kept = items.filter(\.isDone).count
        return Button {
            guard !isSelected else { return }
            Haptics.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { onSelect(day) }
        } label: {
            VStack(spacing: 4) {
                Text(day.weekdayShortText.capitalizedFirst)
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text("\(Calendar.app.component(.day, from: day))")
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(isToday ? Theme.orange : Theme.textPrimary)
                VStack(spacing: 4) {
                    if RestDays.contains(day) {
                        Image(systemName: "moon.zzz.fill")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    } else if items.isEmpty {
                        Text("–")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    ForEach(items.prefix(Self.maxDots)) { task in
                        Circle()
                            .fill(WeekTaskRow(task: task).statusIcon.color)
                            .frame(width: 8, height: 8)
                    }
                    if items.count > Self.maxDots {
                        Text("+\(items.count - Self.maxDots)")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(minHeight: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Theme.textPrimary : Theme.border, lineWidth: isSelected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(items.isEmpty
                            ? "\(day.longDayText), bez úkolů"
                            : "\(day.longDayText), splněno \(kept) z \(items.count)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
