import SwiftUI
import SwiftData

/// Every weekly self-reflection ever written, newest first.
struct JournalView: View {
    @Query(sort: \WeekReflection.weekStart, order: .reverse) private var reflections: [WeekReflection]
    @State private var editing: ReflectionRequest?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sebereflexe týdne")
                    .scaledFont(.title, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                if reflections.isEmpty {
                    Text("Zatím tu nic není. První zápis vznikne v neděli večer při sebereflexi týdne.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .card()
                }
                ForEach(reflections) { reflection in
                    entry(reflection)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .fullScreenCover(item: $editing) { ReflectionView(weekStart: $0.weekStart) }
    }

    private func entry(_ reflection: WeekReflection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TÝDEN \(reflection.weekStart.weekNumber) · \(reflection.weekStart.dayMonthText) – \(reflection.weekStart.addingDays(6).dayMonthText)")
                    .labelStyle()
                Spacer()
                Button("Upravit") { editing = ReflectionRequest(weekStart: reflection.weekStart) }
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 5) {
                ForEach(1...5, id: \.self) { value in
                    Circle()
                        .fill(value <= reflection.satisfaction ? Theme.textPrimary : Theme.cardRaised)
                        .frame(width: 10, height: 10)
                }
                Text(reflection.satisfactionLabel)
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.leading, 4)
            }
            Text("Splněno \(reflection.doneCount) z \(reflection.totalCount) · sliby \(reflection.promisesKept.percentText) · produktivita \(reflection.productivity.percentText)")
                .scaledFont(.caption)
                .foregroundStyle(Theme.textSecondary)
            if !reflection.text.isEmpty {
                Text(reflection.text)
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
                WeeklyReviewView(weekStart: reflection.weekStart)
            } label: {
                Text("Přehled týdne ›")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
    }
}
