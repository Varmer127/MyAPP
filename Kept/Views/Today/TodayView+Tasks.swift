import SwiftUI
import SwiftData

extension TodayView {
    func declinedToday(_ now: Date) -> Set<String> {
        let parts = declinedSuggestions.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0] == "\(now.daySeed)" else { return [] }
        return Set(parts[1].split(separator: ",").map(String.init))
    }

    /// Today's suggestions without the ones declined for the day.
    func visibleSuggestions(now: Date) -> [Suggestion] {
        let declined = declinedToday(now)
        let settings = settingsList.first
        return SuggestionService.suggestions(
            tasks: tasks,
            workoutPresets: settings?.workoutPresets ?? UserSettings.defaultWorkoutPresets,
            now: now,
            target: { settings?.weeklyTarget(for: $0) ?? $0.defaultWeeklyTarget }
        ).filter { !declined.contains($0.category.rawValue) }
    }

    @ViewBuilder
    func suggestionsSection(now: Date) -> some View {
        let declined = declinedToday(now)
        let suggestions = visibleSuggestions(now: now)
        if !suggestions.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Návrhy")
                ForEach(suggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Label(suggestion.category.suggestionTitle, systemImage: suggestion.category.icon)
                                .scaledFont(.heading, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                            Text(suggestion.reason)
                                .scaledFont(.caption)
                                .foregroundStyle(suggestion.isUrgent ? Theme.orange : Theme.textSecondary)
                            if let hint = suggestion.hint {
                                Text(hint)
                                    .scaledFont(.caption, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Text("+\(PointsService.perSuggestion) bodů za splnění")
                                .scaledFont(.caption, weight: .semibold)
                                .foregroundStyle(Theme.green)
                        }
                        HStack(spacing: 10) {
                            Button("PŘIDAT NA DNES") {
                                editor = EditorRequest(date: now, suggestion: suggestion.category)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button("DNES NE") {
                                let all = declined.union([suggestion.category.rawValue])
                                withAnimation { declinedSuggestions = "\(now.daySeed):\(all.sorted().joined(separator: ","))" }
                            }
                            .buttonStyle(SecondaryButtonStyle(textColor: Theme.textSecondary))
                        }
                    }
                    .card()
                }
            }
        }
    }

    func section(_ title: String, color: Color = Theme.textSecondary, tasks: [TaskItem], now: Date) -> some View {
        VStack(spacing: 10) {
            SectionLabel(text: title, color: color)
            ForEach(tasks) { task in
                TaskCard(
                    task: task,
                    now: now,
                    warning: PatternDetectionService.warning(for: task, tasks: self.tasks, failures: failures, now: now),
                    onTap: {
                        if task.status == .pending, !task.isMissed(now) {
                            editor = EditorRequest(task: task)
                        } else {
                            detailTask = task
                        }
                    },
                    onDone: { confirmDone = task },
                    onFail: { giveUp(on: task, now: now) },
                    onFocus: {
                        if task.category == .gym {
                            // The workout starts before the screen opens, so nothing on this screen
                            // changes under the opening animation.
                            _ = task.startFocusIfNeeded(in: context)
                            gymTimerTask = task
                        } else {
                            focusTask = task
                        }
                    },
                    onPartial: { partialTask = task },
                    onStop: { stopTask = task }
                )
                // A closed task shrinks away and the card settles into "Uzavřené".
                .transition(.asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity),
                                        removal: .scale(scale: 0.9).combined(with: .opacity)))
                .matchedTransitionSource(id: task.uid, in: zoom)
                .contextMenu {
                    if task.canReopen(now: now) {
                        Button("Změnit rozhodnutí") { withAnimation { task.reopen() } }
                    }
                }
            }
        }
    }
}
