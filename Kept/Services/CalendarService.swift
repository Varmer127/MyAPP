import EventKit
import Foundation

/// Read-only look into the iPhone's calendars, so a plan can be checked against what is already booked.
/// Nothing is written to the calendar and nothing read from it is stored.
enum CalendarService {
    struct Event: Identifiable, Hashable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool

        /// "10:00–12:00 Zkouška" or "celý den · Dovolená"
        var summary: String {
            isAllDay ? "celý den · \(title)" : "\(start.timeText)–\(end.timeText) \(title)"
        }
    }

    private static let store = EKEventStore()

    static var isAuthorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    /// The user already answered the system question with "no"; only iPhone Settings can change that.
    static var isDenied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted || status == .writeOnly
    }

    /// Shows the system permission question the first time; afterwards just reports the answer.
    @discardableResult
    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Events that touch the given span, in time order. Empty without permission.
    static func events(from start: Date, to end: Date) -> [Event] {
        guard isAuthorized, start < end else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { $0.status != .canceled }
            .map { Event(id: "\($0.eventIdentifier ?? "")-\($0.startDate.timeIntervalSince1970)", title: $0.title ?? "Událost",
                         start: $0.startDate, end: $0.endDate, isAllDay: $0.isAllDay) }
            .sorted { $0.start < $1.start }
    }

    static func events(on day: Date) -> [Event] {
        events(from: day.startOfDay, to: day.endOfDay)
    }

    /// Timed events that overlap the span. All-day events are context, not a clash.
    static func conflicts(start: Date, end: Date, in events: [Event]) -> [Event] {
        events.filter { !$0.isAllDay && $0.start < end && $0.end > start }
    }
}
