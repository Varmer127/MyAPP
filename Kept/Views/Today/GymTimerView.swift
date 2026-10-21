import SwiftUI
import SwiftData

/// The live workout: exercises set by set, last time's numbers alongside, a rest timer with its own
/// start button, and a record banner when a set beats the best so far.
/// Built on FocusSession, where a "pause" is one rest between sets.
struct GymTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// Empty = the preset at the top of the list in the gym settings. A choice lasts only for this workout.
    @State private var selectedName = ""
    @State private var showsLibrary = false
    @State private var record: RecordBanner?
    @State private var savedTemplate = false
    @Query private var settingsList: [UserSettings]
    @Query private var tasks: [TaskItem]
    let task: TaskItem
    /// Called when the user ends the workout meaning to complete the task.
    let onComplete: () -> Void

    struct RecordBanner: Identifiable, Equatable {
        let id = UUID()
        let exercise: String
        let text: String
    }

    private var session: FocusSession? { task.activeFocusSession }
    private var settings: UserSettings? { settingsList.first }
    private var isSimple: Bool { settings?.gymMode == .simple }
    private var presets: [RestPreset] { settings?.restPresets ?? RestPreset.defaults }
    private var preset: RestPreset { presets.first { $0.name == selectedName } ?? presets[0] }
    private var target: TimeInterval { TimeInterval(preset.seconds) }
    private var logs: [ExerciseLog] { task.exercises.sorted { $0.date < $1.date } }
    /// Everything logged in other workouts, the history the numbers are compared with.
    private var history: [TaskItem] { tasks.filter { $0 !== task } }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
        .screenBackground()
        .appAppearance()
        .sheet(isPresented: $showsLibrary) {
            ExerciseLibraryView(own: settings?.exercisePresets ?? []) { add($0) }
        }
        .overlay(alignment: .top) {
            if let record {
                recordBanner(record)
                    .id(record.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.record = nil }
                    }
            }
        }
        .sensoryFeedback(.success, trigger: record) { _, new in new != nil }
        .onAppear {
            task.startFocusIfNeeded(in: context)
            if task.workoutType.isEmpty, let first = settings?.workoutPresets.first {
                pickWorkout(first, loadTemplate: logs.isEmpty && !isSimple)
            }
            // Coming back to a workout keeps the rest length it had on the lock screen.
            if selectedName.isEmpty, let seconds = WidgetSnapshot.load()?.gym?.restSeconds,
               let match = presets.first(where: { $0.seconds == seconds }) {
                selectedName = match.name
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .task {
            // The lock screen stopwatch starts once the screen has finished opening.
            try? await Task.sleep(for: .seconds(0.6))
            syncOutside()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: selectedName) {
            // A different length during a rest moves its end notification too.
            guard let since = session?.pausedSince else { return }
            let remaining = target - Date.now.timeIntervalSince(since)
            NotificationManager.cancelRestEnd()
            if remaining > 0 {
                Task { await NotificationManager.scheduleRestEnd(in: remaining) }
            }
        }
        .onChange(of: selectedName) { syncOutside() }
        .onChange(of: session?.pausedSince) { syncOutside() }
        .onChange(of: task.workoutType) { syncOutside() }
    }

    /// Keeps the stopwatch on the lock screen and in the widget in step with this screen.
    private func syncOutside() {
        GymActivityManager.sync(task: task, rest: preset)
    }

    // MARK: Layout

    private func content(now: Date) -> some View {
        let total = (session?.active(at: now) ?? 0) + (session?.paused(at: now) ?? 0)
        let rest = session?.pausedSince.map { now.timeIntervalSince($0) }
        return Group {
            if isSimple {
                simpleContent(now: now, total: total, rest: rest)
            } else {
                advancedContent(total: total, rest: rest)
            }
        }
        .sensoryFeedback(trigger: (rest ?? 0) >= target) { _, isReached in isReached ? .success : nil }
    }

    /// Simple mode: one big clock, rest statistics and a single button that starts and ends a rest.
    private func simpleContent(now: Date, total: TimeInterval, rest: TimeInterval?) -> some View {
        let reached = (rest ?? 0) >= target
        let finishedRests = max((session?.pauseCount ?? 0) - (rest == nil ? 0 : 1), 0)
        let averageRest = finishedRests > 0 ? (session?.pauseSeconds ?? 0) / Double(finishedRests) : nil
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skrýt") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text(rest == nil ? "TRÉNINK" : (reached ? "JDI NA DALŠÍ SÉRII" : "PAUZA"))
                            .labelStyle(rest == nil ? Theme.textSecondary : (reached ? Theme.green : Theme.orange))
                        Text(FocusView.clock(rest ?? total))
                            .font(.system(size: 76, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        if let rest {
                            ThinBar(value: rest / target, color: reached ? Theme.green : Theme.orange)
                                .frame(width: 220)
                            Text("Cíl \(FocusView.clock(target)) · celkem \(FocusView.clock(total))")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text((task.workoutType.isEmpty ? task.title : task.workoutType).uppercased())
                                .font(.system(size: 17, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .padding(.top, 16)
                    HStack(spacing: 10) {
                        MetricTile(value: "\(session?.pauseCount ?? 0)", label: "Pauzy")
                        MetricTile(value: averageRest.map(FocusView.clock) ?? "—", label: "Průměrná pauza")
                        MetricTile(value: FocusView.minutes(session?.paused(at: now) ?? 0), label: "V pauzách")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        restPicker
                        Text("Orientačně: síla (těžké váhy, 1–5 opakování) 2–5 min, růst svalů 1–2 min, vytrvalost kolem 30 s. U dřepů a mrtvých tahů počítej s delší pauzou než u izolovaných cviků. Je to obecné vodítko, ne rada na míru – hlavní je zvládnout další sérii se stejnou technikou. Vlastní délky pauz si nastavíš v Nastavení gymu.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            VStack(spacing: 10) {
                Button(rest == nil ? "PAUZA MEZI SÉRIEMI" : "DALŠÍ SÉRIE") {
                    if rest == nil { startRest() } else { endRest() }
                }
                .buttonStyle(PrimaryButtonStyle(color: rest == nil ? Theme.textPrimary : (reached ? Theme.green : Theme.orange)))
                Button("DOKONČIT TRÉNINK") { end(completing: true) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Ukončit bez splnění") { end(completing: false) }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 36)
            }
            .padding(Theme.screenPadding)
        }
    }

    /// Advanced mode: exercises set by set under a fixed header with the rest bar.
    private func advancedContent(total: TimeInterval, rest: TimeInterval?) -> some View {
        VStack(spacing: 0) {
            header(total: total, rest: rest)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    workoutPicker
                    ForEach(logs) { log in
                        ExerciseCard(log: log, history: history, onTick: { set in tick(set, of: log) },
                                     onRemove: { remove(log) })
                    }
                    Button {
                        showsLibrary = true
                    } label: {
                        Label("PŘIDAT CVIK", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    if !logs.isEmpty, !task.workoutType.isEmpty {
                        Button(savedTemplate ? "Uloženo jako šablona „\(task.workoutType)“" : "Uložit cviky jako šablonu „\(task.workoutType)“") {
                            settings?.setTemplate(logs.map(\.name), for: task.workoutType)
                            try? context.save()
                            withAnimation { savedTemplate = true }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(savedTemplate ? Theme.green : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 8) {
                Button("DOKONČIT TRÉNINK") { end(completing: true) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Ukončit bez splnění") { end(completing: false) }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 36)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 10)
        }
    }

    private func header(total: TimeInterval, rest: TimeInterval?) -> some View {
        let reached = (rest ?? 0) >= target
        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TRÉNINK").labelStyle()
                    Text(FocusView.clock(total))
                        .font(.system(size: 28, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                Button("Skrýt") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
            // Always the same height, so starting a rest never shifts the rows under the finger.
            VStack(spacing: 6) {
                HStack {
                    if let rest {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reached ? "ODPOČINUTO" : "PAUZA").labelStyle(reached ? Theme.green : Theme.orange)
                            Text("\(FocusView.clock(rest)) / \(FocusView.clock(target))")
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        // A real button, so it does not read as part of the status.
                        Button { endRest() } label: {
                            Label("DALŠÍ SÉRIE", systemImage: "forward.fill")
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(Color(hex: 0x000000))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .background(reached ? Theme.green : Theme.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PAUZA").labelStyle()
                            Text(FocusView.clock(target))
                                .font(.system(size: 15, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button { startRest() } label: {
                            Label("ZAČÍT PAUZU", systemImage: "timer")
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(Theme.onPrimary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .background(Theme.textPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minHeight: 40)
                ThinBar(value: rest.map { $0 / target } ?? 0, color: reached ? Theme.green : Theme.orange)
                restPicker
                    .padding(.top, 4)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var workoutPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CO DNES JEDEŠ").labelStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(settings?.workoutPresets ?? [], id: \.self) { name in
                        let isOn = task.workoutType == name
                        Button { pickWorkout(name, loadTemplate: !isSimple && logs.allSatisfy { log in !log.setLogs.contains(where: \.isDone) }) } label: {
                            Text(name)
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                                .background(isOn ? Theme.textPrimary : Theme.card)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// A segmented control gets cramped beyond a few choices.
    private static let maxSegments = 4

    /// Switching the rest length: a labelled row of choices showing each length, a menu when there are many.
    private var restPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DÉLKA PAUZY").labelStyle()
            if presets.count <= Self.maxSegments {
                HStack(spacing: 4) {
                    ForEach(presets) { item in
                        let isOn = item.name == preset.name
                        Button { selectedName = item.name } label: {
                            VStack(spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(FocusView.clock(TimeInterval(item.seconds)))
                                    .font(.system(size: 12, weight: .medium))
                                    .monospacedDigit()
                                    .opacity(0.7)
                            }
                            .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isOn ? Theme.textPrimary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pauza \(item.name), \(FocusView.clock(TimeInterval(item.seconds)))")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(3)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .sensoryFeedback(.selection, trigger: preset.name)
            } else {
                Picker("Délka pauzy", selection: Binding(get: { preset.name }, set: { selectedName = $0 })) {
                    ForEach(presets) { Text("\($0.name) · \(FocusView.clock(TimeInterval($0.seconds)))").tag($0.name) }
                }
                .pickerStyle(.menu)
                .tint(Theme.textPrimary)
            }
        }
    }

    private func recordBanner(_ banner: RecordBanner) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: 0x000000))
            VStack(alignment: .leading, spacing: 2) {
                Text("NOVÝ REKORD").font(.system(size: 12, weight: .heavy)).tracking(1).foregroundStyle(Color(hex: 0x000000))
                Text("\(banner.exercise) · \(banner.text)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x000000))
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.green)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .shadow(color: Theme.green.opacity(0.35), radius: 12, y: 4)
    }

    // MARK: Actions

    /// Chooses what is trained today. With nothing done yet, the workout's exercises are loaded straight away.
    private func pickWorkout(_ name: String, loadTemplate: Bool) {
        task.workoutType = name
        savedTemplate = false
        defer { try? context.save() }
        guard loadTemplate else { return }
        for log in logs where !log.setLogs.contains(where: \.isDone) {
            remove(log)
        }
        for exercise in settings?.template(for: name) ?? [] {
            add(exercise)
        }
    }

    /// Adds an exercise with last time's working sets ready to tick off, or three empty sets.
    private func add(_ name: String) {
        guard !task.exercises.contains(where: { $0.name.activityKey == name.activityKey }) else { return }
        let log = ExerciseLog(name: name, weight: 0, reps: 0, sets: 0)
        log.task = task
        context.insert(log)
        let previous = GymService.last(name, in: history)?.workingSets ?? []
        let plan = previous.isEmpty ? Array(repeating: (weight: 0.0, reps: 8), count: 3) : previous
        for (index, set) in plan.enumerated() {
            let entry = SetLog(order: index, weight: set.weight, reps: set.reps, isWarmup: false)
            entry.log = log
            context.insert(entry)
        }
        try? context.save()
    }

    private func remove(_ log: ExerciseLog) {
        context.delete(log)
        try? context.save()
    }

    /// Ticking a set off checks for a new record. The rest is started with its own button, never by ticking.
    private func tick(_ set: SetLog, of log: ExerciseLog) {
        set.isDone.toggle()
        try? context.save()
        guard set.isDone else { return }
        if !set.isWarmup, set.weight > 0 {
            let best = GymService.bestMax(log.name, in: history)
            let done = log.orderedSets.filter { $0.isDone && !$0.isWarmup && $0 !== set }
            let bestToday = done.map { ExerciseLog.estimatedMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            let value = ExerciseLog.estimatedMax(weight: set.weight, reps: set.reps)
            if best > 0, value > best, value > bestToday {
                withAnimation(.spring(duration: 0.4)) {
                    record = RecordBanner(exercise: log.name, text: "\(set.weight.kilogramText) × \(set.reps), odhad maxima \(value.kilogramText)")
                }
            }
        }
    }

    /// Starting a rest schedules a notification for the target time, so it also works with the screen locked.
    private func startRest() {
        guard let session else { return }
        if session.isPaused { session.resume() }
        session.pause()
        let seconds = target
        Task { await NotificationManager.scheduleRestEnd(in: seconds) }
    }

    private func endRest() {
        guard let session, session.isPaused else { return }
        session.resume()
        NotificationManager.cancelRestEnd()
    }

    /// Completing leaves the session running until the workout log is saved, like the focus timer.
    private func end(completing: Bool) {
        NotificationManager.cancelRestEnd()
        GymActivityManager.end()
        if completing {
            // The rest in progress ends here, so time spent filling in the log is not counted as a pause.
            if session?.isPaused == true { session?.resume() }
            for log in task.exercises where !log.settle() {
                context.delete(log)
            }
            try? context.save()
        } else {
            task.finishFocusSessions()
        }
        dismiss()
        if completing {
            onComplete()
        }
    }
}

/// One exercise of the live workout with its sets.
private struct ExerciseCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var log: ExerciseLog
    let history: [TaskItem]
    let onTick: (SetLog) -> Void
    let onRemove: () -> Void
    @State private var confirmsRemove = false

    private var catalog: CatalogExercise? { ExerciseCatalog.named(log.name) }

    var body: some View {
        let sets = log.orderedSets
        let last = GymService.last(log.name, in: history)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(log.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let catalog {
                        Text(catalog.primary.map(\.title).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Menu {
                    Button("Odebrat cvik", role: .destructive) { confirmsRemove = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 32)
                }
                .accessibilityLabel("Možnosti cviku")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .swipeToDelete("Odebrat cvik", cornerRadius: 8) { confirmsRemove = true }
            if let hint = GymService.suggestion(for: log.name, in: history) {
                Label(hint, systemImage: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
            HStack(spacing: 8) {
                Text("SÉRIE").frame(width: 40, alignment: .leading)
                Text("MINULE").frame(maxWidth: .infinity, alignment: .leading)
                Text("KG").frame(width: 66)
                Text("OPAK.").frame(width: 50)
                Text("").frame(width: 40)
                Text("").frame(width: SetRow.deleteWidth)
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Theme.textTertiary)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, number: workingNumber(of: set, in: sets),
                       previous: previous(index: index, of: sets, last: last), onTick: { onTick(set) },
                       onDelete: { delete(set) })
            }
            HStack(spacing: 16) {
                Button { addSet(warmup: false) } label: { Label("Série", systemImage: "plus") }
                Button { addSet(warmup: true) } label: { Label("Rozcvička", systemImage: "flame") }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(minHeight: 36)
            if let tip = catalog?.tip {
                Text(tip)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .alert("Odebrat \(log.name)?", isPresented: $confirmsRemove) {
            Button("Odebrat", role: .destructive, action: onRemove)
            Button("Zrušit", role: .cancel) {}
        }
    }

    private func delete(_ set: SetLog) {
        withAnimation(.easeOut(duration: 0.2)) {
            context.delete(set)
        }
        try? context.save()
    }

    /// Warm-ups are marked "R"; working sets are numbered on their own.
    private func workingNumber(of set: SetLog, in sets: [SetLog]) -> String {
        if set.isWarmup { return "R" }
        return "\((sets.filter { !$0.isWarmup }.firstIndex { $0 === set } ?? 0) + 1)"
    }

    private func previous(index: Int, of sets: [SetLog], last: ExerciseLog?) -> String {
        guard let last, !sets[index].isWarmup else { return "–" }
        let working = sets.filter { !$0.isWarmup }
        let position = working.firstIndex { $0 === sets[index] } ?? 0
        let previous = last.workingSets
        guard position < previous.count else { return "–" }
        let set = previous[position]
        return set.weight > 0 ? "\(set.weight.kilogramText) × \(set.reps)" : "\(set.reps) opak."
    }

    /// A warm-up goes before the working sets at about half the weight; a working set repeats the last one.
    private func addSet(warmup: Bool) {
        let sets = log.orderedSets
        let base = sets.last { !$0.isWarmup }
        let entry: SetLog
        if warmup {
            for set in sets { set.order += 1 }
            entry = SetLog(order: 0, weight: ((base?.weight ?? 0) / 2 / 2.5).rounded() * 2.5, reps: 10, isWarmup: true)
        } else {
            entry = SetLog(order: (sets.map(\.order).max() ?? -1) + 1, weight: base?.weight ?? 0, reps: base?.reps ?? 8, isWarmup: false)
        }
        entry.log = log
        context.insert(entry)
        try? context.save()
    }
}

/// One set. It is removed with the cross at the end of the row, or by swiping it to the left.
private struct SetRow: View {
    @Bindable var set: SetLog
    let number: String
    let previous: String
    let onTick: () -> Void
    let onDelete: () -> Void
    static let deleteWidth: CGFloat = 26

    var body: some View {
        row
            .swipeToDelete(set.isWarmup ? "Smazat rozcvičku" : "Smazat sérii", cornerRadius: 8, onDelete: onDelete)
        .opacity(set.isWarmup && !set.isDone ? 0.75 : 1)
        .animation(.easeOut(duration: 0.15), value: set.isDone)
        // Every number goes to disk as it is typed, so a crash or a killed app loses nothing.
        .onChange(of: set.weight) { save() }
        .onChange(of: set.reps) { save() }
        .onChange(of: set.isWarmup) { save() }
    }

    private func save() {
        try? set.modelContext?.save()
    }

    private var row: some View {
        HStack(spacing: 8) {
            Menu {
                Button(set.isWarmup ? "Změnit na pracovní sérii" : "Změnit na rozcvičku") { set.isWarmup.toggle() }
                Button("Smazat sérii", role: .destructive, action: onDelete)
            } label: {
                Text(number)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(set.isWarmup ? Theme.orange : Theme.textPrimary)
                    .frame(width: 40, height: 36)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel(set.isWarmup ? "Rozcvičovací série" : "Série \(number)")
            Text(previous)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...2)).locale(.app))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 66, height: 36)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Váha v kilogramech")
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 50, height: 36)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Počet opakování")
            Button(action: onTick) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(set.isDone ? Color(hex: 0x000000) : Theme.textTertiary)
                    .frame(width: 40, height: 36)
                    .background(set.isDone ? Theme.green : Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isDone ? "Série hotová" : "Odškrtnout sérii")
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: Self.deleteWidth, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isWarmup ? "Smazat rozcvičku" : "Smazat sérii \(number)")
        }
    }
}
