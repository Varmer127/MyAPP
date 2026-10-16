import SwiftUI
import SwiftData

/// The live workout: exercises set by set, last time's numbers alongside, a rest timer that starts
/// when a set is ticked off, and a record banner when a set beats the best so far.
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
                pickWorkout(first, loadTemplate: logs.isEmpty)
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: Layout

    private func content(now: Date) -> some View {
        let total = (session?.active(at: now) ?? 0) + (session?.paused(at: now) ?? 0)
        let rest = session?.pausedSince.map { now.timeIntervalSince($0) }
        return VStack(spacing: 0) {
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
                            withAnimation { savedTemplate = true }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(savedTemplate ? Theme.green : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    restPicker
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
        .sensoryFeedback(trigger: (rest ?? 0) >= target) { _, isReached in isReached ? .success : nil }
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
            // Always there, so ticking a set off never shifts the rows under the finger.
            VStack(spacing: 6) {
                HStack {
                    if let rest {
                        Text(reached ? "JDI NA DALŠÍ SÉRII" : "PAUZA").labelStyle(reached ? Theme.green : Theme.orange)
                        Spacer()
                        Text("\(FocusView.clock(rest)) / \(FocusView.clock(target))")
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textPrimary)
                        Button("Konec pauzy") { endRest() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.leading, 8)
                    } else {
                        Text("PAUZA SE SPUSTÍ PO ODŠKRTNUTÍ SÉRIE").labelStyle()
                        Spacer()
                        Text(FocusView.clock(target))
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(minHeight: 24)
                ThinBar(value: rest.map { $0 / target } ?? 0, color: reached ? Theme.green : Theme.orange)
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
                        Button { pickWorkout(name, loadTemplate: logs.allSatisfy { log in !log.setLogs.contains(where: \.isDone) }) } label: {
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

    private var restPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAUZA PO SÉRII").labelStyle()
            Picker("Pauza", selection: Binding(get: { preset.name }, set: { selectedName = $0 })) {
                ForEach(presets) { Text("\($0.name) · \(FocusView.clock(TimeInterval($0.seconds)))").tag($0.name) }
            }
            .pickerStyle(.menu)
            .tint(Theme.textPrimary)
        }
        .padding(.top, 8)
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
    }

    /// Ticking a set off starts the rest and checks for a new record.
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
        startRest()
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
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Theme.textTertiary)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, number: workingNumber(of: set, in: sets),
                       previous: previous(index: index, of: sets, last: last), onTick: { onTick(set) })
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
    }
}

private struct SetRow: View {
    @Bindable var set: SetLog
    let number: String
    let previous: String
    let onTick: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button(set.isWarmup ? "Změnit na pracovní sérii" : "Změnit na rozcvičku") { set.isWarmup.toggle() }
                Button("Smazat sérii", role: .destructive) { set.modelContext?.delete(set) }
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
                .minimumScaleFactor(0.8)
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
        }
        .opacity(set.isWarmup && !set.isDone ? 0.75 : 1)
        .animation(.easeOut(duration: 0.15), value: set.isDone)
    }
}
