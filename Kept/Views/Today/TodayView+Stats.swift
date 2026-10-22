import SwiftUI
import SwiftData

extension TodayView {
    func hero(_ day: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // A new user starts with a clean record, not with dashes.
            Text("\(day.accountability?.score ?? ScoreEngine.startingScore)")
                .scaledFont(.hero, weight: .heavy)
                .foregroundStyle(heroFlash ?? (day.accountability == nil ? Theme.green : heroColor(day.accountability?.score)))
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.6), value: day.accountability?.score)
                .animation(.easeOut(duration: 0.4), value: heroFlash)
            HStack(spacing: 8) {
                Text("SPOLEHLIVOST · 30 DNÍ").labelStyle()
                if day.accountability == nil {
                    Badge(text: "Čistý štít", color: Theme.green)
                }
            }
            Text(day.accountability?.subtitle ?? "Startuješ na plných 100. Zatím jsi nic neporušil. Odešli plánovač na týden a udrž to tak.")
                .scaledFont(.body)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 4)
        }
    }

    /// How many days before today had anything planned. The reliability score says nothing before a week of them.
    func daysOfHistory(now: Date) -> Int {
        Set(tasks.filter { !$0.isRemoved && $0.countsInScores && $0.scheduledDate < now.startOfDay }
            .map { $0.scheduledDate.startOfDay }).count
    }

    /// Reliability, the three tiles and the points on one card that opens when touched, below the day's tasks.
    /// Until a week of history exists it does not show a score: a new user gets "collecting data", not a made-up 100.
    func statsStrip(_ day: TodaySnapshot, now: Date) -> some View {
        let enough = daysOfHistory(now: now) >= Self.daysBeforeScore
        let score = day.accountability?.score ?? ScoreEngine.startingScore
        let balance = PointsService.balance(tasks, purchases: purchases, diary: diary)
        return VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { statsExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    if enough {
                        Text("\(score)")
                            .scaledFont(.title, weight: .heavy)
                            .foregroundStyle(heroFlash ?? heroColor(score))
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.4), value: heroFlash)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(enough ? "SPOLEHLIVOST" : "SPOLEHLIVOST · SBÍRÁME DATA").labelStyle()
                        Text(enough ? "\(day.freshValue(day.promisesKept)) dodržených slibů · série \(String.days(day.streak)) · \(balance.formatted(.number.locale(.app))) bodů"
                                    : "Ukáže se po prvním týdnu · \(balance.formatted(.number.locale(.app))) bodů")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .scaledFont(.caption, weight: .bold)
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(statsExpanded ? 180 : 0))
                }
                .card()
            }
            .buttonStyle(.plain)
            .accessibilityHint(statsExpanded ? "Skryje podrobnosti" : "Ukáže podrobnosti")
            // The number blinks green when it rises and orange when it falls, then settles.
            .onChange(of: day.accountability?.score) { old, new in
                guard let old, let new, old != new else { return }
                heroFlash = new > old ? Theme.green : Theme.orange
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    heroFlash = nil
                }
            }
            if statsExpanded {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    if enough {
                        hero(day)
                        metrics(day)
                    }
                    pointsCard
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    func heroColor(_ score: Int?) -> Color {
        guard let score else { return Theme.textTertiary }
        return Double(score) / 100 < Theme.poorThreshold ? Theme.red : Theme.textPrimary
    }

    func metrics(_ day: TodaySnapshot) -> some View {
        TileRow {
            MetricTile(value: day.freshValue(day.promisesKept), label: "Dodržené sliby")
            MetricTile(value: day.freshValue(day.productivity), label: "Produktivita")
            MetricTile(value: "\(day.streak)", label: "Série dní")
        }
    }
}
