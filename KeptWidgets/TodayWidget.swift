import AppIntents
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    /// The snapshot only describes the day it was written on.
    var today: WidgetSnapshot? {
        guard let snapshot, Calendar.current.isDate(snapshot.day, inSameDayAs: date) else { return nil }
        return snapshot
    }
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: WidgetSnapshot(day: .now, score: 81, done: 3, total: 5, streak: 4,
                                                        promisesKept: 0.86, nextTitle: "Claude Work"))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : TodayEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // The app reloads the widget on every change. By itself it only goes stale at midnight
        // and at the moment a running focus timer passes its planned end.
        let now = Date.now
        let snapshot = WidgetSnapshot.load()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)
        var dates = [now, midnight]
        if let focus = snapshot?.focus, !focus.isPaused, focus.endDate > now, focus.endDate < midnight {
            dates.insert(focus.endDate, at: 1)
        }
        // The gym widgets switch from "rest" to "next set" when the rest runs out.
        if let restEnd = snapshot?.gym?.restEnd, restEnd > now, restEnd < midnight {
            dates.append(restEnd)
        }
        dates.sort()
        completion(Timeline(entries: dates.map { TodayEntry(date: $0, snapshot: snapshot) }, policy: .after(midnight)))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeptToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(WidgetStyle.background, for: .widget)
        }
        .configurationDisplayName("Kept – dnes")
        .description("Spolehlivost, dnešní úkoly, série a běžící focus.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private static let orange = WidgetStyle.orange
    private static let green = WidgetStyle.green
    private static let grey = WidgetStyle.secondary

    private var snapshot: WidgetSnapshot? { entry.today }
    private var focus: WidgetSnapshot.Focus? { snapshot?.focus }
    private var done: Int { snapshot?.done ?? 0 }
    private var total: Int { snapshot?.total ?? 0 }
    private var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }
    private var streak: Int { entry.snapshot?.streak ?? 0 }

    var body: some View {
        switch family {
        case .accessoryCircular:
            if let focus {
                VStack(spacing: 1) {
                    Image(systemName: focus.isPaused ? "pause.fill" : "timer").font(.system(size: 12))
                    timerText(focus)
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Gauge(value: progress) {
                    Image(systemName: "checkmark")
                } currentValueLabel: {
                    Text("\(done)/\(total)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
        case .accessoryRectangular:
            if let focus {
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusText(focus)).font(.caption2)
                    Text(focus.title).font(.headline).lineLimit(1)
                    timerText(focus).font(.title3.weight(.bold))
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kept · \(done) / \(total) splněno").font(.headline)
                    Text(snapshot?.nextTitle.map { "Další: \($0)" } ?? (total == 0 ? "Dnes nic v plánu" : "Všechno hotovo"))
                        .font(.caption)
                    Label("\(streak)", systemImage: "flame.fill").font(.caption)
                }
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                summary
                if let focus {
                    focusPanel(focus, timerSize: 34)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        label("DALŠÍ ÚKOL")
                        Text(snapshot?.nextTitle ?? (total == 0 ? "Dnes nic v plánu" : "Všechno hotovo"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WidgetStyle.text)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        if let id = snapshot?.nextCompletableID {
                            Button(intent: CompleteTaskIntent(taskID: id)) {
                                Label("HOTOVO", systemImage: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Self.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        } else {
                            label("DODRŽENÉ SLIBY")
                            Text(snapshot?.promisesKept.map { "\(Int(($0 * 100).rounded())) %" } ?? "—")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(WidgetStyle.text)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        default:
            if let focus {
                focusPanel(focus, timerSize: 36)
            } else {
                summary
            }
        }
    }

    // MARK: Focus

    private func isOvertime(_ focus: WidgetSnapshot.Focus) -> Bool {
        focus.isPaused ? focus.remainingSeconds < 0 : focus.endDate <= entry.date
    }

    private func isBehind(_ focus: WidgetSnapshot.Focus) -> Bool {
        isOvertime(focus) && focus.hasDeadline == true
    }

    private func statusText(_ focus: WidgetSnapshot.Focus) -> String {
        focus.isPaused ? "FOCUS POZASTAVEN" : (isBehind(focus) ? "NESTÍHÁŠ PLÁN" : (isOvertime(focus) ? "NAD PLÁN" : "FOCUS BĚŽÍ"))
    }

    /// Running: a system-driven timer that keeps ticking without the app. Paused: the frozen time.
    @ViewBuilder
    private func timerText(_ focus: WidgetSnapshot.Focus) -> some View {
        if focus.isPaused {
            Text(Self.clock(focus.remainingSeconds)).monospacedDigit()
        } else {
            Text(focus.endDate, style: .timer).monospacedDigit()
        }
    }

    private func focusPanel(_ focus: WidgetSnapshot.Focus, timerSize: CGFloat) -> some View {
        let highlighted = focus.isPaused || isBehind(focus)
        return VStack(alignment: .leading, spacing: 6) {
            Text(statusText(focus))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(highlighted ? Self.orange : Self.grey)
            Text(focus.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WidgetStyle.text)
                .lineLimit(2)
            Spacer(minLength: 0)
            timerText(focus)
                .font(.system(size: timerSize, weight: .heavy))
                .foregroundStyle(WidgetStyle.text)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func clock(_ seconds: Double) -> String {
        let total = Int(abs(seconds))
        let rest = String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
        let text = total >= 3600 ? "\(total / 3600):\(rest)" : rest
        return seconds < 0 ? "+\(text)" : text
    }

    // MARK: Day summary

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                label("SPOLEHLIVOST")
                Spacer(minLength: 0)
                Label("\(streak)", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(streak > 0 ? Self.orange : Self.grey)
            }
            Text(entry.snapshot?.score.map { "\($0)" } ?? "—")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(WidgetStyle.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(done) / \(total) splněno")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WidgetStyle.text)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(WidgetStyle.track)
                    Capsule().fill(total > 0 && done == total ? Self.green : WidgetStyle.text)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Self.grey)
    }
}
