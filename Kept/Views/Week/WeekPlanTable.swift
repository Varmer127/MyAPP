import SwiftUI

/// The planned week at a glance: one row per activity, one column per day.
/// Shown before the plan is sent, so nothing chosen in a hurry slips through.
struct WeekPlanTable: View {
    let tasks: [TaskItem]
    let weekStart: Date

    private struct Row: Identifiable {
        let id: String
        let title: String
        let icon: String
        let perDay: [Int]
        var total: Int { perDay.reduce(0, +) }
    }

    private static let dayColumn: CGFloat = 26
    private static let totalColumn: CGFloat = 30

    private var days: [Date] { (0..<7).map { weekStart.addingDays($0) } }

    /// Tasks with the same name form one row, ordered like the categories and then by name.
    private var rows: [Row] {
        let groups = Dictionary(grouping: tasks) { $0.title.activityKey }
        return groups.values.compactMap { group -> Row? in
            guard let first = group.first else { return nil }
            let perDay = days.map { day in group.filter { $0.scheduledDate.isSameDay(as: day) }.count }
            return Row(id: first.title.activityKey, title: first.title, icon: first.icon, perDay: perDay)
        }
        .sorted { lhs, rhs in
            let left = order(of: lhs), right = order(of: rhs)
            return left == right ? lhs.title.localizedCompare(rhs.title) == .orderedAscending : left < right
        }
    }

    private func order(of row: Row) -> Int {
        let category = tasks.first { $0.title.activityKey == row.id }?.category ?? .other
        return TaskCategory.allCases.firstIndex(of: category) ?? 0
    }

    var body: some View {
        let rows = rows
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text("AKTIVITA").labelStyle().frame(maxWidth: .infinity, alignment: .leading)
                ForEach(days, id: \.self) { day in
                    Text(day.weekdayShortText.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Self.dayColumn)
                }
                Text("Σ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Self.totalColumn)
            }
            .padding(.bottom, 8)
            ForEach(rows) { row in
                Divider().overlay(Theme.border)
                HStack(spacing: 4) {
                    Label {
                        Text(row.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } icon: {
                        Image(systemName: row.icon).font(.system(size: 12))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(0..<7, id: \.self) { index in
                        cell(row.perDay[index])
                    }
                    Text("\(row.total)")
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: Self.totalColumn)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText(row))
            }
            Divider().overlay(Theme.border)
            HStack(spacing: 4) {
                Text("CELKEM").labelStyle().frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<7, id: \.self) { index in
                    let count = rows.reduce(0) { $0 + $1.perDay[index] }
                    Text(count > 0 ? "\(count)" : "–")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(count > 0 ? Theme.textPrimary : Theme.textTertiary)
                        .frame(width: Self.dayColumn)
                }
                Text("\(tasks.count)")
                    .font(.system(size: 14, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: Self.totalColumn)
            }
            .padding(.top, 8)
        }
        .card(padding: 14)
    }

    private func cell(_ count: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(count > 0 ? Theme.textPrimary : Theme.cardRaised)
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.onPrimary)
            }
        }
        .frame(width: Self.dayColumn - 4, height: Self.dayColumn - 4)
        .frame(width: Self.dayColumn)
    }

    private func accessibilityText(_ row: Row) -> String {
        let planned = zip(days, row.perDay).filter { $0.1 > 0 }
            .map { $0.1 > 1 ? "\($0.0.weekdayShortText) \($0.1)×" : $0.0.weekdayShortText }
        return "\(row.title): \(planned.joined(separator: ", ")), celkem \(row.total)"
    }
}
