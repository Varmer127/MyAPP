import SwiftUI
import SwiftData

extension TodayView {
    /// The day's promise when the big card has scrolled away: how many are kept and the streak, in one thin line.
    func compactBar(_ day: TodaySnapshot) -> some View {
        let done = day.doneCount
        let total = day.visible.count
        return HStack(spacing: 10) {
            Text("\(done) / \(total)")
                .scaledFont(.body, weight: .heavy)
                .foregroundStyle(done == total ? Theme.green : Theme.textPrimary)
            ThinBar(value: Double(done) / Double(max(total, 1)), color: done == total ? Theme.green : Theme.textPrimary)
            Label("\(day.streak)", systemImage: "flame.fill")
                .scaledFont(.caption, weight: .heavy)
                .foregroundStyle(day.streak > 0 ? Theme.orange : Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dnešní slib \(done) z \(total), série \(String.days(day.streak))")
    }

    /// What else is still open today, under the next task: an overview, nothing to do here.
    /// Two ways to show it are tried side by side (switch in the developer section): boxes, or a line that unfolds.
    @ViewBuilder
    func upcoming(_ others: [TaskItem]) -> some View {
        if upcomingStyle == 0 {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(others) { task in
                    HStack(spacing: 6) {
                        Image(systemName: task.icon)
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Text(task.title)
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Dál čeká: \(others.map(\.title).joined(separator: ", "))")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { upcomingExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Text("a další \(others.count)")
                            .scaledFont(.caption, weight: .semibold)
                        Image(systemName: "chevron.down")
                            .scaledFont(.caption, weight: .bold)
                            .rotationEffect(.degrees(upcomingExpanded ? 180 : 0))
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if upcomingExpanded {
                    ForEach(others) { task in
                        Label(task.title, systemImage: task.icon)
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    func header(now: Date, day: TodaySnapshot) -> some View {
        let streak = day.streak
        let atRisk = streakAtRisk(day, now: now)
        // The date, the flame and the add button share one row; at very large text they stack instead.
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                dateBlock(now: now, atRisk: atRisk, streak: streak)
                Spacer(minLength: 8)
                addButton
                flame(streak: streak, atRisk: atRisk)
            }
            VStack(alignment: .leading, spacing: 12) {
                dateBlock(now: now, atRisk: atRisk, streak: streak)
                HStack(spacing: 12) {
                    addButton
                    Spacer()
                    flame(streak: streak, atRisk: atRisk)
                }
            }
        }
        .padding(.top, 8)
    }

    func dateBlock(now: Date, atRisk: Bool, streak: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DNES").labelStyle()
            Text(now.longDayText)
                // Smaller than the title size so the date, the add button and the flame fit in one row.
                .scaledFont(24, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if atRisk {
                Text("Série zhasne o půlnoci")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.orange)
            } else if RestDays.contains(now) {
                Label("Odpočinkový den. Série čeká.", systemImage: "moon.zzz.fill")
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    /// Days in a row at 80 % or better. Lit only while the streak is alive, breathing slowly;
    /// in the evening of a day that would break it, it pulses.
    func flame(streak: Int, atRisk: Bool) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "flame.fill")
                .scaledFont(.title)
                .symbolEffect(.bounce, options: .nonRepeating, value: streak)
                .symbolEffect(.pulse, options: .repeating, isActive: atRisk && !reduceMotion)
                .symbolEffect(.breathe, options: .repeating, isActive: streak > 0 && !atRisk && !reduceMotion)
            Text("\(streak)")
                .scaledFont(.body, weight: .heavy)
                .contentTransition(.numericText())
        }
        .foregroundStyle(streak > 0 ? Theme.orange : Theme.textTertiary)
        .overlay { SparkBurst(trigger: sparkTrigger) }
        .animation(.easeOut(duration: 0.4), value: streak)
        .onChange(of: streak) { old, new in
            if new > old { sparkTrigger += 1; Haptics.medium() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak == 0 ? "Série zatím nezačala, začni ji dnes"
                            : (atRisk ? "Série \(String.days(streak)), o půlnoci zhasne" : "Série \(String.days(streak))"))
    }

    var addButton: some View {
        Button {
            Haptics.light()
            editor = EditorRequest(date: .now)
        } label: {
            Label("ÚKOL", systemImage: "plus")
                .scaledFont(.caption, weight: .heavy)
                .tracking(0.6)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Theme.cardRaised)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Přidat úkol")
    }

    /// The streak is alive from earlier days, but today is still under the bar and the evening has come.
    func streakAtRisk(_ day: TodaySnapshot, now: Date) -> Bool {
        day.streak > 0 && now.minutesIntoDay >= Self.streakWarningFromMinutes
            && !RestDays.contains(now) && !day.scored.isEmpty && (day.productivity ?? 0) < ScoreEngine.Config.streakThreshold
    }

    /// Today's promise in one card: how much is kept, what comes next, and the way to start it.
    @ViewBuilder
    func todaysPromise(_ day: TodaySnapshot, now: Date) -> some View {
        if day.visible.isEmpty {
            emptyState
        } else {
            // A sealed promise that was taken out of the plan is gone from the list and cannot be done any more:
            // it shows as a broken promise of its own and does not hold the progress of what is left.
            let total = day.visible.count
            let done = day.doneCount
            let broken = day.scored.count - day.visible.count
            let next = (day.critical + day.open).first
            let allDone = done == total && broken == 0
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("DNEŠNÍ SLIB").labelStyle(allDone ? Theme.green : Theme.textSecondary)
                    Spacer()
                    if broken > 0 {
                        Text("porušeno: \(broken)")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.red)
                    }
                    if day.partialCount > 0 {
                        Text("částečně: \(day.partialCount)")
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.orange)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(done) / \(total)")
                        .scaledFont(34, weight: .heavy)
                        .foregroundStyle(allDone ? Theme.green : Theme.textPrimary)
                        .contentTransition(.numericText())
                    Text(allDone ? "Den dodržen." : (done == total ? "Zbytek je splněný." : (total - done == 1 ? "Zbývá poslední." : "Zbývá \(total - done).")))
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                }
                ThinBar(value: Double(done) / Double(total), color: allDone ? Theme.green : Theme.textPrimary)
                if let next {
                    HStack(spacing: 10) {
                        Image(systemName: next.icon)
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Theme.cardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NA ŘADĚ").labelStyle()
                            Text(next.title)
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if next.activeFocusSession == nil, next.category == .gym || next.usesFocus {
                            Button(next.category == .gym ? "ZAČÍT" : "FOCUS") {
                                if next.category == .gym {
                                    _ = next.startFocusIfNeeded(in: context)
                                    gymTimerTask = next
                                } else {
                                    focusTask = next
                                }
                            }
                            .scaledFont(.caption, weight: .heavy)
                            .foregroundStyle(Theme.onPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Theme.textPrimary)
                            .clipShape(Capsule())
                        } else if !next.requiresProof, next.category != .gym {
                            Button("SPLNIL JSEM") { confirmDone = next }
                                .scaledFont(.caption, weight: .heavy)
                                .foregroundStyle(Color(hex: 0x000000))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(Theme.green)
                                .clipShape(Capsule())
                        }
                    }
                }
                let others = Array((day.critical + day.open).dropFirst())
                if !others.isEmpty {
                    upcoming(others)
                }
            }
            .card()
            .overlay { SweepHighlight(trigger: allDone) }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(promiseFlash ?? .clear, lineWidth: 2)
                    .opacity(promiseFlash == nil ? 0 : 1)
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 0.3), value: done)
            .onChange(of: allDone) { old, new in
                if new && !old { Haptics.success() }
            }
            .onChange(of: broken) { old, new in
                guard new > old else { return }
                promiseFlash = Theme.red
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    withAnimation(.easeOut(duration: 0.4)) { promiseFlash = nil }
                }
            }
        }
    }
}
