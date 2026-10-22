import Foundation
import Testing
@testable import Kept

@MainActor
struct ExportTests {
    @Test func theDiaryIsOnlyInTheFileWhenAskedFor() throws {
        let context = try Fixture.context()
        let task = Fixture.task("Čtení", day: 0, done: true)
        context.insert(task)
        let entry = DiaryEntry(day: Fixture.now, question: "Co dnes?")
        entry.answer = "Šlo to."
        context.insert(entry)

        let without = DataExport.build(tasks: [task], plans: [], failures: [], diary: nil, now: Fixture.now)
        let with = DataExport.build(tasks: [task], plans: [], failures: [], diary: [entry], now: Fixture.now)
        #expect(without.diary == nil)
        #expect(with.diary?.first?.answer == "Šlo to.")
        #expect(without.tasks.first?.title == "Čtení")
    }

    @Test func theFileIsWrittenAsReadableJSON() throws {
        let file = DataExport.build(tasks: [Fixture.task("Gym", category: .gym)], plans: [], failures: [], diary: nil, now: Fixture.now)
        let url = try DataExport.write(file)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("\"title\" : \"Gym\""))
        #expect(url.lastPathComponent.hasPrefix("Kept-"))
    }
}
