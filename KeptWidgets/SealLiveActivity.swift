import ActivityKit
import SwiftUI
import WidgetKit

/// The hour before a weekly plan is sealed, on the lock screen and in the Dynamic Island.
/// The system ticks the timer itself; once the time is up the activity goes stale and shows the plan as sealed.
struct SealLiveActivity: Widget {
    private static let orange = Color(red: 1.0, green: 0.62, blue: 0.04)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SealActivityAttributes.self) { context in
            let sealed = isSealed(context)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(sealed ? "PLÁNOVAČ ZAPEČETĚN" : "PLÁNOVAČ · ZAPEČETĚNÍ",
                          systemImage: sealed ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Self.orange)
                        .lineLimit(1)
                    Text("Týden \(context.attributes.weekNumber) · závazky: \(context.state.commitments)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(sealed ? "Od teď se každá změna počítá." : "Úpravy zatím bez postihu.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                if sealed {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                } else {
                    timerText(context)
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 130, alignment: .trailing)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("PLÁNOVAČ", systemImage: isSealed(context) ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Self.orange)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(isSealed(context) ? "Týden \(context.attributes.weekNumber) je zapečetěný"
                         : "Týden \(context.attributes.weekNumber) · závazky: \(context.state.commitments)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: isSealed(context) ? "lock.fill" : "lock.open.fill").foregroundStyle(Self.orange)
            } compactTrailing: {
                timerText(context)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: isSealed(context) ? "lock.fill" : "lock.open.fill").foregroundStyle(Self.orange)
            }
        }
    }

    private func isSealed(_ context: ActivityViewContext<SealActivityAttributes>) -> Bool {
        context.isStale || context.state.sealDate <= .now
    }

    /// Counts down to the seal time and stops at zero.
    private func timerText(_ context: ActivityViewContext<SealActivityAttributes>) -> some View {
        Text(timerInterval: min(Date.now, context.state.sealDate)...context.state.sealDate, countsDown: true)
            .monospacedDigit()
    }
}
