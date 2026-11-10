import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The gym stopwatch on the lock screen and in the Dynamic Island: the workout time counting up,
/// the rest counting down, and one button to start or end a rest.
struct GymLiveActivity: Widget {
    private static let orange = Color(red: 1.0, green: 0.62, blue: 0.04)
    private static let green = Color(red: 0.19, green: 0.82, blue: 0.35)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GymActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRÉNINK · \(context.state.workout.uppercased())")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        workoutClock(context)
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(context.state.heldTotal == nil ? .white : .white.opacity(0.6))
                    }
                    Spacer()
                    controls(context)
                }
                restBar(context)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.heldTotal == nil ? "TRÉNINK" : "ČAS STOJÍ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(context.state.heldTotal == nil ? .white.opacity(0.6) : Self.orange)
                        workoutClock(context)
                            .font(.system(size: 22, weight: .bold))
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    controls(context)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    restBar(context)
                }
            } compactLeading: {
                Image(systemName: compactSymbol(context))
                    .foregroundStyle(isResting(context) || context.state.heldTotal != nil ? Self.orange : .white)
            } compactTrailing: {
                Group {
                    if let start = context.state.restStart, let end = context.state.restEnd, !restIsOver(context) {
                        Text(timerInterval: start...end, countsDown: true)
                    } else {
                        workoutClock(context)
                    }
                }
                .monospacedDigit()
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: compactSymbol(context))
            }
        }
    }

    private func isResting(_ context: ActivityViewContext<GymActivityAttributes>) -> Bool {
        context.state.restStart != nil
    }

    private func restIsOver(_ context: ActivityViewContext<GymActivityAttributes>) -> Bool {
        guard let end = context.state.restEnd else { return false }
        return context.isStale || end <= .now
    }

    @ViewBuilder
    private func restBar(_ context: ActivityViewContext<GymActivityAttributes>) -> some View {
        if let start = context.state.restStart, let end = context.state.restEnd {
            let over = restIsOver(context)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(over ? "JDI NA DALŠÍ SÉRII" : "PAUZA")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(over ? Self.green : Self.orange)
                    Spacer()
                    if !over {
                        Text(timerInterval: start...end, countsDown: true)
                            .font(.system(size: 15, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.trailing)
                    }
                }
                ProgressView(timerInterval: start...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(over ? Self.green : Self.orange)
            }
        } else {
            Text("Pauza \(context.state.restName) · \(WidgetStyle.clock(Double(context.state.restSeconds)))")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func compactSymbol(_ context: ActivityViewContext<GymActivityAttributes>) -> String {
        context.state.heldTotal != nil ? "pause.fill" : (isResting(context) ? "pause.circle.fill" : "dumbbell.fill")
    }

    /// The workout time: ticking while it runs, standing still while the clock is stopped.
    @ViewBuilder
    private func workoutClock(_ context: ActivityViewContext<GymActivityAttributes>) -> some View {
        if let held = context.state.heldTotal {
            Text(WidgetStyle.clock(held)).monospacedDigit()
        } else {
            Text(context.state.startDate, style: .timer).monospacedDigit()
        }
    }

    /// Running: stop the clock, and start or end a rest. Stopped: one button to start it again.
    @ViewBuilder
    private func controls(_ context: ActivityViewContext<GymActivityAttributes>) -> some View {
        if context.state.heldTotal != nil {
            Button(intent: GymHoldIntent(hold: false)) {
                Label("SPUSTIT ČAS", systemImage: "play.fill")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Self.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 8) {
                Button(intent: GymHoldIntent(hold: true)) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zastavit čas")
                restButton(context)
            }
        }
    }

    private func restButton(_ context: ActivityViewContext<GymActivityAttributes>) -> some View {
        let resting = isResting(context)
        return Button(intent: GymRestIntent(start: !resting)) {
            Label(resting ? "DALŠÍ SÉRIE" : "PAUZA", systemImage: resting ? "forward.fill" : "timer")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(resting ? (restIsOver(context) ? Self.green : Self.orange) : .white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
