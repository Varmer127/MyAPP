import Foundation
import OSLog
import SwiftData

extension Notification.Name {
    /// Posted when a change could not be written to disk, so the app can tell the user instead of failing silently.
    static let persistenceFailed = Notification.Name("kept.persistenceFailed")
}

/// The one place where changes are written. A failed write is logged and shown to the user once in a while;
/// before this, every call site used `try?` and a lost change was never noticed.
enum Persistence {
    private static let logger = Logger(subsystem: "cz.philipstryka.kept", category: "persistence")
    nonisolated(unsafe) private static var lastAnnounced = Date.distantPast
    private static let announceGap: TimeInterval = 60

    static func save(_ context: ModelContext?) {
        guard let context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Only the kind of error is logged: the message can contain the content of what failed to save.
            logger.error("Save failed: \(String(describing: type(of: error)), privacy: .public)")
            guard Date.now.timeIntervalSince(lastAnnounced) > announceGap else { return }
            lastAnnounced = .now
            NotificationCenter.default.post(name: .persistenceFailed, object: nil)
        }
    }
}
