import Foundation
import SwiftData

/// Everything the user entered, as one JSON file they can keep: promises, weeks, failures and, only when asked, the diary.
/// Photos are not included. The file only ever leaves through the system share sheet, which the user controls.
enum DataExport {
    struct File: Codable {
        var app = "Kept"
        var version: String
        var exportedAt: Date
        var tasks: [ExportTask]
        var weeks: [ExportWeek]
        var failures: [ExportFailure]
        var diary: [ExportDiary]?
    }

    struct ExportTask: Codable {
        var title: String
        var category: String
        var priority: String
        var weight: Int
        var plannedMinutes: Int
        var day: Date
        var deadline: Date?
        var status: String
        var completedAt: Date?
        var sealed: Bool
        var removed: Bool
        var why: String
        var cue: String
        var notes: String
        var stake: String
        var workout: String
    }

    struct ExportWeek: Codable {
        var weekStart: Date
        var submittedAt: Date?
        var sealedAt: Date?
    }

    struct ExportFailure: Codable {
        var date: Date
        var task: String
        var kind: String
        var reason: String
        var critique: String
        var prevention: String
    }

    struct ExportDiary: Codable {
        var day: Date
        var question: String
        var answer: String
        var wentWell: String
        var wentBadly: String
        var doDifferently: String
        var gratitude: String
        var mood: Int
        var energy: Int
    }

    static func build(tasks: [TaskItem], plans: [WeeklyPlan], failures: [FailureRecord], diary: [DiaryEntry]?, now: Date = .now) -> File {
        File(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            exportedAt: now,
            tasks: tasks.sorted { $0.scheduledDate < $1.scheduledDate }.map {
                ExportTask(title: $0.title, category: $0.category.title, priority: $0.priority.rawValue, weight: $0.weight,
                           plannedMinutes: $0.plannedMinutes, day: $0.scheduledDate, deadline: $0.deadline,
                           status: $0.status.rawValue, completedAt: $0.completedAt, sealed: $0.isCommitted, removed: $0.isRemoved,
                           why: $0.why, cue: $0.cue, notes: $0.notes, stake: $0.stake, workout: $0.workoutSummary ?? "")
            },
            weeks: plans.sorted { $0.weekStart < $1.weekStart }.map {
                ExportWeek(weekStart: $0.weekStart, submittedAt: $0.submittedAt, sealedAt: $0.committedAt)
            },
            failures: failures.sorted { $0.date < $1.date }.map {
                ExportFailure(date: $0.date, task: $0.taskTitle, kind: $0.kind.rawValue, reason: $0.reason.rawValue,
                              critique: $0.critique, prevention: $0.prevention)
            },
            diary: diary?.sorted { $0.day < $1.day }.map {
                ExportDiary(day: $0.day, question: $0.question, answer: $0.answer, wentWell: $0.wentWell, wentBadly: $0.wentBadly,
                            doDifferently: $0.doDifferently, gratitude: $0.gratitude, mood: $0.mood, energy: $0.energy)
            })
    }

    /// Writes the file into the temporary folder, replacing earlier exports, and returns where it is.
    static func write(_ file: File) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("KeptExport", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = file.exportedAt.formatted(.iso8601.year().month().day())
        let url = folder.appendingPathComponent("Kept-\(stamp).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
