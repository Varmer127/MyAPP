import SwiftUI
import SwiftData

/// What the rest between sets is aiming for.
enum RestStyle: String, CaseIterable, Identifiable {
    case strength, muscle, endurance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Síla"
        case .muscle: "Svaly"
        case .endurance: "Vytrvalost"
        }
    }

    /// Target rest in seconds: a sensible middle of the commonly recommended range.
    var targetSeconds: TimeInterval {
        switch self {
        case .strength: 180
        case .muscle: 90
        case .endurance: 30
        }
    }
}

/// Workout stopwatch: total time counting up, and rest between sets measured against a target.
/// Built on FocusSession, where a "pause" is one rest between sets.
struct GymTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("gymRestStyle") private var styleRaw = RestStyle.muscle.rawValue
    let task: TaskItem
    /// Called when the user ends the workout meaning to complete the task.
    let onComplete: () -> Void

    private var session: FocusSession? { task.activeFocusSession }
    private var style: RestStyle { RestStyle(rawValue: styleRaw) ?? .muscle }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
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
        let reached = (rest ?? 0) >= style.targetSeconds
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
                            ThinBar(value: rest / style.targetSeconds, color: reached ? Theme.green : Theme.orange)
                                .frame(width: 220)
                            Text("Cíl \(FocusView.clock(style.targetSeconds)) · celkem \(FocusView.clock(total))")
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
                        Picker("Typ tréninku", selection: $styleRaw) {
                            ForEach(RestStyle.allCases) { Text($0.title).tag($0.rawValue) }
                        }
                        .pickerStyle(.segmented)
                        Text("Orientačně: síla (těžké váhy, 1–5 opakování) 2–5 min, růst svalů 1–2 min, vytrvalost kolem 30 s. U dřepů a mrtvých tahů počítej s delší pauzou než u izolovaných cviků. Je to obecné vodítko, ne rada na míru – hlavní je zvládnout další sérii se stejnou technikou.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            VStack(spacing: 10) {
                Button(rest == nil ? "PAUZA MEZI SÉRIEMI" : "DALŠÍ SÉRIE", action: toggleRest)
                    .buttonStyle(PrimaryButtonStyle(color: rest == nil ? .white : (reached ? Theme.green : Theme.orange)))
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
            let seconds = style.targetSeconds
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
