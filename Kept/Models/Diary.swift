import Foundation
import SwiftData

/// One day of the self-reflection diary. Every part is optional; one entry per day.
@Model
final class DiaryEntry {
    /// Start of the day the entry is about.
    var day: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// The question of the day as it was asked, so old entries keep their own question.
    var question: String = ""
    var answer: String = ""
    var wentWell: String = ""
    var wentBadly: String = ""
    var doDifferently: String = ""
    var gratitude: String = ""
    /// 1 (very low) … 5 (great); 0 = not filled in.
    var mood: Int = 0
    var energy: Int = 0

    init(day: Date, question: String, now: Date = .now) {
        self.day = day.startOfDay
        self.question = question
        self.createdAt = now
        self.updatedAt = now
    }

    var texts: [String] { [answer, wentWell, wentBadly, doDifferently, gratitude] }

    /// Something was really written. Only such an entry earns points and keeps the writing streak.
    var hasWriting: Bool { texts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
}

/// A letter to one's future self: written now, readable only once `opensAt` has come.
@Model
final class FutureLetter {
    var writtenAt: Date = Date()
    var opensAt: Date = Date()
    var text: String = ""
    var openedAt: Date?

    init(text: String, opensAt: Date, now: Date = .now) {
        self.text = text
        self.opensAt = opensAt
        self.writtenAt = now
    }

    func isDue(_ now: Date = .now) -> Bool { opensAt <= now }
}
