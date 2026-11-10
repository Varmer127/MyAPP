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
    @State private var confirmsStop = false
    @State private var confirmsClear = false
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
        .confirmationDialog("Smazat všechny cviky?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Smazat všechny cviky", role: .destructive) { clearExercises() }
            Button("Nechat", role: .cancel) {}
        } message: {
            Text("Z tohoto tréninku zmizí všechny cviky i se sériemi. Stopky běží dál. Vrátit to nejde.")
        }
        .confirmationDialog("Ukončit trénink?", isPresented: $confirmsStop, titleVisibility: .visible) {
            Button("Ukončit bez splnění", role: .destructive) { end(completing: false) }
            Button("Pokračovat v tréninku", role: .cancel) {}
        } message: {
            Text("Trénink skončí a úkol zůstane otevřený. Zapsané cviky zůstanou. Jen na chvíli přerušit můžeš tlačítkem Zastavit čas.")
        }
        .onAppear {
            task.startFocusIfNeeded(in: context)
            // The workout starts empty; the template is one tap away, never filled in on its own.
            if task.workoutType.isEmpty, let first = settings?.workoutPresets.first {
                pickWorkout(first, loadTemplate: false)
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
        .onChange(of: session?.heldSince) { syncOutside() }
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
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text(isHeld ? "ČAS STOJÍ" : (rest == nil ? "TRÉNINK" : (reached ? "JDI NA DALŠÍ SÉRII" : "PAUZA")))
                            .labelStyle(isHeld ? Theme.orange : (rest == nil ? Theme.textSecondary : (reached ? Theme.green : Theme.orange)))
                        Text(FocusView.clock(rest ?? total))
                            .scaledFont(76, weight: .heavy)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        if let rest {
                            ThinBar(value: rest / target, color: reached ? Theme.green : Theme.orange)
                                .frame(width: 220)
                            Text("Cíl \(FocusView.clock(target)) · celkem \(FocusView.clock(total))")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text((task.workoutType.isEmpty ? task.title : task.workoutType).uppercased())
                                .scaledFont(.heading, weight: .semibold)
                                .tracking(1)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        holdButton
                            .padding(.top, 6)
                    }
                    .padding(.top, 16)
                    TileRow {
                        MetricTile(value: "\(session?.pauseCount ?? 0)", label: "Pauzy")
                        MetricTile(value: averageRest.map(FocusView.clock) ?? "—", label: "Průměrná pauza")
                        MetricTile(value: FocusView.minutes(session?.paused(at: now) ?? 0), label: "V pauzách")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        restPicker
                        Text("Orientačně: síla (těžké váhy, 1–5 opakování) 2–5 min, růst svalů 1–2 min, vytrvalost kolem 30 s. U dřepů a mrtvých tahů počítej s delší pauzou než u izolovaných cviků. Je to obecné vodítko, ne rada na míru – hlavní je zvládnout další sérii se stejnou technikou. Vlastní délky pauz si nastavíš v Nastavení gymu.")
                            .scaledFont(.caption)
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
                stopButton
            }
            .padding(Theme.screenPadding)
        }
    }

    private var isHeld: Bool { session?.isHeld == true }

    /// Stops the workout's clock for a while, or starts it again.
    private var holdButton: some View {
        HoldClockButton(isHeld: isHeld) { setHold(!isHeld) }
    }

    private func setHold(_ hold: Bool) {
        GymActivityManager.setHold(hold, task: task, rest: preset)
    }

    /// Ends the workout without completing it, after one question. Same in both modes.
    private var stopButton: some View {
        Button {
            Haptics.medium()
            confirmsStop = true
        } label: {
            Label("UKONČIT BEZ SPLNĚNÍ", systemImage: "xmark")
                .scaledFont(.body, weight: .heavy)
                .tracking(0.6)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(PillButtonStyle(kind: .destructive))
    }

    /// Advanced mode: exercises set by set under a fixed header with the rest bar.
    private func advancedContent(total: TimeInterval, rest: TimeInterval?) -> some View {
        VStack(spacing: 0) {
            header(total: total, rest: rest)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    workoutPicker
                    if logs.isEmpty {
                        emptyWorkout
                    }
                    ForEach(logs) { log in
                        ExerciseCard(log: log, history: history, onTick: { set in tick(set, of: log) },
                                     onRemove: { remove(log) })
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    if !logs.isEmpty {
                        Button {
                            Haptics.light()
                            showsLibrary = true
                        } label: {
                            Label("PŘIDAT CVIK", systemImage: "plus")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    if !logs.isEmpty, !task.workoutType.isEmpty {
                        Button(savedTemplate ? "Uloženo jako šablona „\(task.workoutType)“" : "Uložit cviky jako šablonu „\(task.workoutType)“") {
                            settings?.setTemplate(logs.map(\.name), for: task.workoutType)
                            Persistence.save(context)
                            withAnimation { savedTemplate = true }
                        }
                        .scaledFont(.caption, weight: .semibold)
                        .foregroundStyle(savedTemplate ? Theme.green : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    if !logs.isEmpty {
                        Button {
                            Haptics.medium()
                            confirmsClear = true
                        } label: {
                            Label("Smazat všechny cviky", systemImage: "trash")
                        }
                        .buttonStyle(PillButtonStyle(kind: .destructive))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 16)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: logs.map(\.persistentModelID))
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 8) {
                Button("DOKONČIT TRÉNINK") { end(completing: true) }
                    .buttonStyle(PrimaryButtonStyle())
                stopButton
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
                    Text(isHeld ? "ČAS STOJÍ" : "TRÉNINK").labelStyle(isHeld ? Theme.orange : Theme.textSecondary)
                    Text(FocusView.clock(total))
                        .scaledFont(.title, weight: .heavy)
                        .monospacedDigit()
                        .foregroundStyle(isHeld ? Theme.textSecondary : Theme.textPrimary)
                        .contentTransition(.numericText())
                }
                holdButton
                    .padding(.leading, 6)
                Spacer()
                Button("Skrýt") { dismiss() }
                    .scaledFont(.body)
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
                                .scaledFont(.body, weight: .bold)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Spacer()
                        // A real button, so it does not read as part of the status.
                        Button { endRest() } label: {
                            Label("DALŠÍ SÉRIE", systemImage: "forward.fill")
                                .scaledFont(.caption, weight: .heavy)
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
                                .scaledFont(.body, weight: .bold)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button { startRest() } label: {
                            Label("ZAČÍT PAUZU", systemImage: "timer")
                                .scaledFont(.caption, weight: .heavy)
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
                        Button {
                            Haptics.light()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { pickWorkout(name, loadTemplate: false) }
                        } label: {
                            Text(name)
                                .scaledFont(.body, weight: .semibold)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                                .background(isOn ? Theme.textPrimary : Theme.card)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(PillPressStyle())
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
                                    .scaledFont(.caption, weight: .semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(FocusView.clock(TimeInterval(item.seconds)))
                                    .scaledFont(.caption, weight: .medium)
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
                .scaledFont(.title)
                .foregroundStyle(Color(hex: 0x000000))
            VStack(alignment: .leading, spacing: 2) {
                Text("NOVÝ REKORD").scaledFont(.caption, weight: .heavy).tracking(1).foregroundStyle(Color(hex: 0x000000))
                Text("\(banner.exercise) · \(banner.text)")
                    .scaledFont(.body, weight: .semibold)
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

    /// A fresh workout: one big way to add the first exercise, and the saved template a tap away.
    private var emptyWorkout: some View {
        let template = task.workoutType.isEmpty ? [] : (settings?.template(for: task.workoutType) ?? [])
        return VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .symbolEffect(.bounce, options: .nonRepeating, value: task.workoutType)
                .frame(width: 72, height: 72)
                .background(Theme.cardRaised, in: Circle())
            Text("Začni prvním cvikem")
                .scaledFont(.heading, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            Button {
                Haptics.light()
                showsLibrary = true
            } label: {
                Label("PŘIDAT CVIK", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            if !template.isEmpty {
                Button {
                    Haptics.medium()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        for exercise in template { add(exercise) }
                    }
                } label: {
                    Label("Načíst šablonu „\(task.workoutType)“ · \(template.count) cviků", systemImage: "square.stack.3d.down.right")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .card()
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: Actions

    /// Chooses what is trained today. With nothing done yet, the workout's exercises are loaded straight away.
    private func pickWorkout(_ name: String, loadTemplate: Bool) {
        task.workoutType = name
        savedTemplate = false
        defer { Persistence.save(context) }
        guard loadTemplate else { return }
        for log in logs where !log.setLogs.contains(where: \.isDone) {
            remove(log)
        }
        for exercise in settings?.template(for: name) ?? [] {
            add(exercise)
        }
    }

    /// Adds an exercise with last time's working sets ready to tick off, or three empty sets.
    /// The same exercise can go in twice, for example bench press at the start and again at the end.
    private func add(_ name: String) {
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
        Persistence.save(context)
    }

    /// Empties this workout's list: every exercise with its sets. The clock and the rests are untouched.
    private func clearExercises() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            for log in task.exercises {
                context.delete(log)
            }
        }
        Haptics.success()
        savedTemplate = false
        Persistence.save(context)
    }

    private func remove(_ log: ExerciseLog) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            context.delete(log)
        }
        Haptics.medium()
        Persistence.save(context)
    }

    /// Ticking a set off checks for a new record. The rest is started with its own button, never by ticking.
    private func tick(_ set: SetLog, of log: ExerciseLog) {
        set.isDone.toggle()
        Persistence.save(context)
        guard set.isDone else { return }
        if !set.isWarmup, set.weight > 0, ExerciseLog.plausibleWeight.contains(set.weight),
           ExerciseLog.plausibleReps.contains(set.reps) {
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
        session.unhold()
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
            Persistence.save(context)
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

    var body: some View {
        let sets = log.orderedSets
        let last = GymService.last(log.name, in: history)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ExerciseThumb(name: log.name, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(log.name)
                        .scaledFont(.heading, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    let muscles = ExerciseInfo(log.name).muscleLine
                    if !muscles.isEmpty {
                        Text(muscles)
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                ExerciseInfoButton(name: log.name)
                Menu {
                    Button("Odebrat cvik", systemImage: "trash", role: .destructive) { requestRemove() }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 32)
                }
                .accessibilityLabel("Možnosti cviku")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            if let hint = GymService.suggestion(for: log.name, in: history) {
                Label(hint, systemImage: "arrow.up.right")
                    .scaledFont(.caption, weight: .semibold)
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
            .scaledFont(.caption, weight: .semibold)
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
            .scaledFont(.body, weight: .semibold)
            .foregroundStyle(Theme.textPrimary)
            .frame(minHeight: 36)
        }
        .card()
        // Swiping the whole card to the left removes the exercise; a set inside is still swiped away on its own.
        .swipeToDelete("Odebrat cvik", cornerRadius: Theme.radius) { requestRemove() }
        .alert("Odebrat \(log.name)?", isPresented: $confirmsRemove) {
            Button("Odebrat", role: .destructive, action: onRemove)
            Button("Zrušit", role: .cancel) {}
        }
    }

    /// An exercise with nothing done yet goes straight away; one with done sets asks first.
    private func requestRemove() {
        if log.setLogs.contains(where: \.isDone) { confirmsRemove = true } else { onRemove() }
    }

    private func delete(_ set: SetLog) {
        withAnimation(.easeOut(duration: 0.2)) {
            context.delete(set)
        }
        Persistence.save(context)
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
        Persistence.save(context)
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

    /// Above what anyone lifts or repeats in a set: almost surely a typo, like "8282" for "82,5".
    static let implausibleWeight = ExerciseLog.plausibleWeight.upperBound
    static let implausibleReps = ExerciseLog.plausibleReps.upperBound

    private var warning: String? {
        if set.weight > Self.implausibleWeight {
            return "\(set.weight.kilogramText) je nejspíš překlep. Zkontroluj váhu, jinak ti pokazí rekordy."
        }
        if set.reps > Self.implausibleReps {
            return "\(set.reps) opakování je nejspíš překlep. Zkontroluj počet."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row
                .swipeToDelete(set.isWarmup ? "Smazat rozcvičku" : "Smazat sérii", cornerRadius: 8, onDelete: onDelete)
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(.caption, weight: .medium)
                    .foregroundStyle(Theme.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: warning)
        .opacity(set.isWarmup && !set.isDone ? 0.75 : 1)
        .animation(.easeOut(duration: 0.15), value: set.isDone)
        // Every number goes to disk as it is typed, so a crash or a killed app loses nothing.
        .onChange(of: set.weight) { save() }
        .onChange(of: set.reps) { save() }
        .onChange(of: set.isWarmup) { save() }
    }

    private func save() {
        Persistence.save(set.modelContext)
    }

    private var row: some View {
        HStack(spacing: 8) {
            Menu {
                Button(set.isWarmup ? "Změnit na pracovní sérii" : "Změnit na rozcvičku") { set.isWarmup.toggle() }
                Button("Smazat sérii", role: .destructive, action: onDelete)
            } label: {
                Text(number)
                    .scaledFont(.body, weight: .heavy)
                    .foregroundStyle(set.isWarmup ? Theme.orange : Theme.textPrimary)
                    .frame(width: 40, height: 36)
                    .background(Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel(set.isWarmup ? "Rozcvičovací série" : "Série \(number)")
            Text(previous)
                .scaledFont(.caption)
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...2)).locale(.app))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .scaledFont(.body, weight: .semibold)
                .frame(width: 66, height: 36)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.orange, lineWidth: set.weight > Self.implausibleWeight ? 1.5 : 0))
                .accessibilityLabel("Váha v kilogramech")
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .scaledFont(.body, weight: .semibold)
                .frame(width: 50, height: 36)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.orange, lineWidth: set.reps > Self.implausibleReps ? 1.5 : 0))
                .accessibilityLabel("Počet opakování")
            Button(action: onTick) {
                Image(systemName: "checkmark")
                    .scaledFont(.body, weight: .heavy)
                    .foregroundStyle(set.isDone ? Color(hex: 0x000000) : Theme.textTertiary)
                    .frame(width: 40, height: 36)
                    .background(set.isDone ? Theme.green : Theme.cardRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isDone ? "Série hotová" : "Odškrtnout sérii")
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: Self.deleteWidth, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isWarmup ? "Smazat rozcvičku" : "Smazat sérii \(number)")
        }
    }
}
