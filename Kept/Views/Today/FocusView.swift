import SwiftUI
import SwiftData

/// Minimal full-screen timer for one task.
struct FocusView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    /// Called when the user ends the session meaning to complete the task.
    let onComplete: () -> Void

    private var session: FocusSession? { task.activeFocusSession }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            if session == nil {
                context.insert(FocusSession(task: task))
            }
            UIApplication.shared.isIdleTimerDisabled = true
            scheduleEndNotification()
            if let session {
                FocusActivityManager.sync(session, title: task.title)
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func content(now: Date) -> some View {
        let remaining = session?.remaining(at: now) ?? TimeInterval(task.plannedMinutes * 60)
        let isOvertime = remaining < 0
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skrýt") { dismiss() }
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.screenPadding)
            Spacer()
            VStack(spacing: 14) {
                Text(isOvertime ? "PŘES ČAS" : (session?.isPaused == true ? "POZASTAVENO" : "FOCUS"))
                    .labelStyle(isOvertime || session?.isPaused == true ? Theme.orange : Theme.textSecondary)
                Text("\(isOvertime ? "+" : "")\(Self.clock(abs(remaining)))")
                    .font(.system(size: 76, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(task.title.uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.screenPadding)
            Spacer()
            HStack(spacing: 10) {
                MetricTile(value: "\(task.plannedMinutes) min", label: "Plán")
                MetricTile(value: Self.minutes(session?.active(at: now) ?? 0), label: "Soustředění")
                MetricTile(value: Self.minutes(session?.paused(at: now) ?? 0), label: "Pauza \(session?.pauseCount ?? 0)×")
            }
            .padding(.horizontal, Theme.screenPadding)
            VStack(spacing: 10) {
                Button(session?.isPaused == true ? "POKRAČOVAT" : "PAUZA", action: togglePause)
                    .buttonStyle(SecondaryButtonStyle())
                Button("DOKONČIT") { end(completing: true) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Ukončit bez splnění") { end(completing: false) }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
            }
            .padding(Theme.screenPadding)
        }
    }

    /// "59:32" or "1:05:10"
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let hours = total / 3600
        let rest = String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
        return hours > 0 ? "\(hours):\(rest)" : rest
    }

    static func minutes(_ interval: TimeInterval) -> String {
        "\(Int(interval / 60)) min"
    }

    private func togglePause() {
        guard let session else { return }
        Self.togglePause(session, title: task.title)
    }

    /// Pauses or resumes a session and keeps its end-of-time notification in step.
    /// Shared with the timer shown on the task card.
    static func togglePause(_ session: FocusSession, title: String) {
        if session.isPaused {
            session.resume()
            let remaining = session.remaining()
            if remaining > 0 {
                Task { await NotificationManager.scheduleFocusEnd(title: title, in: remaining) }
            }
        } else {
            session.pause()
            NotificationManager.cancelFocusEnd()
        }
        FocusActivityManager.sync(session, title: title)
    }

    private func end(completing: Bool) {
        session?.finish()
        NotificationManager.cancelFocusEnd()
        FocusActivityManager.end()
        dismiss()
        if completing {
            onComplete()
        }
    }

    /// The app cannot count in the background, so the end of the planned time is announced by a notification.
    private func scheduleEndNotification() {
        guard let session, !session.isPaused else { return }
        let remaining = session.remaining()
        guard remaining > 0 else { return }
        let title = task.title
        Task { await NotificationManager.scheduleFocusEnd(title: title, in: remaining) }
    }
}
