import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running focus timer on the lock screen and in the Dynamic Island.
/// The system ticks the timer text itself, so it keeps counting while the app is suspended.
/// Pause and UKONČIT work right there, without opening the app.
struct FocusLiveActivity: Widget {
    private static let orange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let red = Color(red: 1.0, green: 0.27, blue: 0.23)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        statusLabel(context)
                        Text(context.attributes.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("Plán \(context.attributes.plannedMinutes) min")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    timerText(context)
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 150, alignment: .trailing)
                }
                controls(context)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    statusLabel(context).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        Text(context.attributes.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        controls(context)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            } compactTrailing: {
                timerText(context)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            }
        }
    }

    /// Pause or resume, and end. Ending keeps the time and leaves the task open.
    private func controls(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        let paused = context.state.isPaused
        return HStack(spacing: 8) {
            Button(intent: FocusPauseIntent(pause: !paused)) {
                Label(paused ? "POKRAČOVAT" : "PAUZA", systemImage: paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(paused ? Self.orange : .white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button(intent: StopTimerIntent()) {
                Label("UKONČIT", systemImage: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Self.red)
                    .frame(minWidth: 96, minHeight: 36)
                    .background(Self.red.opacity(0.18))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func isOvertime(_ context: ActivityViewContext<FocusActivityAttributes>) -> Bool {
        context.state.isPaused ? context.state.remainingSeconds < 0 : (context.isStale || context.state.endDate <= .now)
    }

    private func statusLabel(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        let overtime = isOvertime(context)
        let behind = overtime && context.attributes.hasDeadline
        let text = context.state.isPaused ? "FOCUS POZASTAVEN" : (behind ? "NESTÍHÁŠ PLÁN" : (overtime ? "NAD PLÁN" : "FOCUS BĚŽÍ"))
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(1)
            .foregroundStyle(context.state.isPaused || behind ? Self.orange : .white.opacity(0.6))
    }

    /// Running: a system-driven timer that counts down to the end and then up into overtime.
    /// Paused: the frozen remaining time.
    @ViewBuilder
    private func timerText(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        if context.state.isPaused {
            Text(Self.clock(context.state.remainingSeconds)).monospacedDigit()
        } else {
            Text(context.state.endDate, style: .timer).monospacedDigit()
        }
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(abs(seconds))
        let rest = String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
        let text = total >= 3600 ? "\(total / 3600):\(rest)" : rest
        return seconds < 0 ? "+\(text)" : text
    }
}
