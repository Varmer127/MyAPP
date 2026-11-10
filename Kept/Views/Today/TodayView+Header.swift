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

    /// What else is still open today, under the next task. It unfolds, and touching one of the others makes it
    /// the main task above (the one with "Splnil jsem"), while the main one takes its place in the list.
    @ViewBuilder
    func upcoming(_ others: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(upcomingExpanded ? "Skryje další úkoly" : "Ukáže další úkoly")
            if upcomingExpanded {
                ForEach(others) { task in
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { pinnedNext = task.uid }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: task.icon)
                                .scaledFont(.body)
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 24)
                            Text(task.title)
                                .scaledFont(.body, weight: .semibold)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up")
                                .scaledFont(.caption, weight: .bold)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Theme.cardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Udělá z něj hlavní úkol")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    func header(now: Date, day: TodaySnapshot) -> some View {
        let streak = day.streak
        let atRisk = streakAtRisk(day, now: now)
        // The date shares a row with the bell and the flame; the add button sits under them, across the width.
        // With larger text the date wraps or shrinks a little instead of pushing the bell and the flame to a row
        // of their own; only at the accessibility sizes do they stack.
        return VStack(alignment: .leading, spacing: 14) {
            if typeSize >= .accessibility1 {
                VStack(alignment: .leading, spacing: 12) {
                    dateBlock(now: now, atRisk: atRisk, streak: streak)
                    HStack(spacing: 12) {
                        Spacer()
                        NotificationBell()
                        flame(streak: streak, atRisk: atRisk)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    dateBlock(now: now, atRisk: atRisk, streak: streak)
                        .layoutPriority(1)
                    Spacer(minLength: 0)
                    NotificationBell()
                        .fixedSize()
                    flame(streak: streak, atRisk: atRisk)
                        .fixedSize()
                }
            }
            HStack(spacing: 10) {
                addButton
                pointsButton
            }
        }
        .padding(.top, 8)
    }

    func dateBlock(now: Date, atRisk: Bool, streak: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DNES").labelStyle()
            Text(now.longDayText)
                // Smaller than the title size so the date, the bell and the flame fit in one row.
                .scaledFont(24, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
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
            Label("PŘIDAT ÚKOL", systemImage: "plus")
                .scaledFont(.caption, weight: .heavy)
                .tracking(0.6)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.cardRaised)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Přidat úkol")
    }

    /// The balance next to the add button; touching it opens the shop.
    var pointsButton: some View {
        let balance = PointsService.balance(tasks, purchases: purchases, diary: diary)
        return Button {
            Haptics.light()
            showsShop = true
        } label: {
            Label {
                Text(balance.formatted(.number.locale(.app)))
                    .contentTransition(.numericText())
            } icon: {
                Image(systemName: "star.fill").foregroundStyle(Theme.orange)
            }
            .scaledFont(.caption, weight: .heavy)
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Theme.cardRaised)
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.3), value: balance)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Body: \(balance), otevřít obchod")
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
            let open = day.critical + day.open
            // The user can pick which open task is the main one; otherwise it is the first.
            let next = open.first { $0.uid == pinnedNext } ?? open.first
            let allDone = done == total && broken == 0
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    ProgressRing(value: Double(done) / Double(total)) {
                        VStack(spacing: 0) {
                            Text("\(done)/\(total)")
                                .scaledFont(26, weight: .heavy)
                                .foregroundStyle(allDone ? Theme.green : Theme.textPrimary)
                                .contentTransition(.numericText())
                            Text("dodrženo")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .frame(width: 104, height: 104)
                    VStack(alignment: .leading, spacing: 4) {
                        if let next {
                            Text("NA ŘADĚ").labelStyle()
                            Text(next.title)
                                .scaledFont(.heading, weight: .heavy)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            Text(next.deadline.map { "do \($0.timeText) · \(next.plannedMinutes) min" } ?? "\(next.plannedMinutes) min")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text(allDone ? "DEN DODRŽEN" : "HOTOVO").labelStyle(Theme.green)
                            Text(allDone ? "Takhle vypadá dodržené slovo." : "Zbytek je splněný.")
                                .scaledFont(.heading, weight: .heavy)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        if broken > 0 || day.partialCount > 0 {
                            HStack(spacing: 8) {
                                if broken > 0 {
                                    Text("porušeno: \(broken)").scaledFont(.caption).foregroundStyle(Theme.red)
                                }
                                if day.partialCount > 0 {
                                    Text("částečně: \(day.partialCount)").scaledFont(.caption).foregroundStyle(Theme.orange)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let next {
                    if next.activeFocusSession == nil, next.category == .gym || next.usesFocus {
                        Button(next.category == .gym ? "ZAČÍT TRÉNINK" : "ZAČÍT FOCUS") {
                            if next.category == .gym {
                                _ = next.startFocusIfNeeded(in: context)
                                gymTimerTask = next
                            } else {
                                focusTask = next
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else if next.activeFocusSession != nil, next.category == .gym || next.usesFocus {
                        // A workout or focus left running in the background is one tap away, and so is stopping it.
                        HStack(spacing: 8) {
                            Button {
                                Haptics.light()
                                if next.category == .gym { gymTimerTask = next } else { focusTask = next }
                            } label: {
                                Label(next.category == .gym ? "POKRAČOVAT V TRÉNINKU" : "POKRAČOVAT VE FOCUSU",
                                      systemImage: "play.fill")
                                    .symbolEffect(.pulse, options: .repeating)
                            }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000)))
                            Button {
                                Haptics.medium()
                                stopTask = next
                            } label: {
                                Image(systemName: "stop.fill")
                                    .scaledFont(.body, weight: .heavy)
                                    .foregroundStyle(Theme.red)
                                    .frame(width: 52, height: 52)
                                    .background(Theme.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(PillPressStyle())
                            .accessibilityLabel(next.category == .gym ? "Zastavit trénink" : "Zastavit časovač")
                        }
                    } else if !next.requiresProof, next.category != .gym {
                        Button("SPLNIL JSEM") { confirmDone = next }
                            .buttonStyle(PrimaryButtonStyle(color: Theme.green, textColor: Color(hex: 0x000000)))
                    }
                }
                let others = open.filter { $0.uid != next?.uid }
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
