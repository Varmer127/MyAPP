import SwiftUI
import SwiftData

/// Workout stopwatch: total time counting up, and rest between sets measured against a target.
/// Built on FocusSession, where a "pause" is one rest between sets.
struct GymTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RestPreset.selectionKey) private var selectedName = ""
    @Query private var settingsList: [UserSettings]
    let task: TaskItem
    /// Called when the user ends the workout meaning to complete the task.
    let onComplete: () -> Void

    private var session: FocusSession? { task.activeFocusSession }
    private var presets: [RestPreset] { settingsList.first?.restPresets ?? RestPreset.defaults }
    private var preset: RestPreset { presets.first { $0.name == selectedName } ?? presets[0] }
    private var target: TimeInterval { TimeInterval(preset.seconds) }

    /// A segmented control gets cramped beyond a few choices.
    private static let maxSegments = 4

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
        .screenBackground()
        .appAppearance()
        .onAppear {
            task.startFocusIfNeeded(in: context)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func content(now: Date) -> some View {
        let total = (session?.active(at: now) ?? 0) + (session?.paused(at: now) ?? 0)
        let rest = session?.pausedSince.map { now.timeIntervalSince($0) }
        let reached = (rest ?? 0) >= target
        let finishedRests = max((session?.pauseCount ?? 0) - (rest == nil ? 0 : 1), 0)
        let averageRest = finishedRests > 0 ? (session?.pauseSeconds ?? 0) / Double(finishedRests) : nil
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skrýt") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.screenPadding)
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
                            Text(task.title.uppercased())
                                .font(.system(size: 17, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .padding(.top, 24)
                    HStack(spacing: 10) {
                        MetricTile(value: "\(session?.pauseCount ?? 0)", label: "Pauzy")
                        MetricTile(value: averageRest.map(FocusView.clock) ?? "—", label: "Průměrná pauza")
                        MetricTile(value: FocusView.minutes(session?.paused(at: now) ?? 0), label: "V pauzách")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        let selection = Binding(get: { preset.name }, set: { selectedName = $0 })
                        if presets.count <= Self.maxSegments {
                            Picker("Pauza", selection: selection) {
                                ForEach(presets) { Text($0.name).tag($0.name) }
                            }
                            .pickerStyle(.segmented)
                        } else {
                            Picker("Pauza", selection: selection) {
                                ForEach(presets) { Text("\($0.name) · \(FocusView.clock(TimeInterval($0.seconds)))").tag($0.name) }
                            }
                            .pickerStyle(.menu)
                            .tint(Theme.textPrimary)
                        }
                        Text("Orientačně: síla (těžké váhy, 1–5 opakování) 2–5 min, růst svalů 1–2 min, vytrvalost kolem 30 s. U dřepů a mrtvých tahů počítej s delší pauzou než u izolovaných cviků. Je to obecné vodítko, ne rada na míru – hlavní je zvládnout další sérii se stejnou technikou. Vlastní délky pauz si nastavíš v Nastavení gymu.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            VStack(spacing: 10) {
                Button(rest == nil ? "PAUZA MEZI SÉRIEMI" : "DALŠÍ SÉRIE", action: toggleRest)
                    .buttonStyle(PrimaryButtonStyle(color: rest == nil ? Theme.textPrimary : (reached ? Theme.green : Theme.orange)))
                Button("DOKONČIT TRÉNINK") { end(completing: true) }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Ukončit bez splnění") { end(completing: false) }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            }
            .padding(Theme.screenPadding)
        }
        .sensoryFeedback(trigger: reached) { _, isReached in isReached ? .success : nil }
    }

    /// Starting a rest schedules a notification for the target time, so it also works with the screen locked.
    private func toggleRest() {
        guard let session else { return }
        if session.isPaused {
            session.resume()
            NotificationManager.cancelRestEnd()
        } else {
            session.pause()
            let seconds = target
            Task { await NotificationManager.scheduleRestEnd(in: seconds) }
        }
    }

    /// Completing leaves the session running until the workout log is saved, like the focus timer.
    private func end(completing: Bool) {
        NotificationManager.cancelRestEnd()
        if completing {
            // The rest in progress ends here, so time spent filling in the log is not counted as a pause.
            if session?.isPaused == true { session?.resume() }
        } else {
            task.finishFocusSessions()
        }
        dismiss()
        if completing {
            onComplete()
        }
    }
}
