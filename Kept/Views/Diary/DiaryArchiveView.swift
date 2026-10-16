import SwiftUI
import SwiftData

/// Everything ever written in the diary, newest first and grouped by month, with search:
/// daily entries, what was written about failures, weekly reflections and opened letters.
struct DiaryArchiveView: View {
    @Query(sort: \DiaryEntry.day, order: .reverse) private var entries: [DiaryEntry]
    @Query(sort: \FailureRecord.date, order: .reverse) private var failures: [FailureRecord]
    @Query(sort: \WeekReflection.weekStart, order: .reverse) private var reflections: [WeekReflection]
    @Query(sort: \FutureLetter.writtenAt, order: .reverse) private var letters: [FutureLetter]
    @State private var search = ""
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Vše", days = "Dny", failures = "Selhání", weeks = "Týdny"
        var id: String { rawValue }
    }

    private enum Item: Identifiable {
        case entry(DiaryEntry)
        case failure(FailureRecord)
        case week(WeekReflection)
        case letter(FutureLetter)

        var id: String {
            switch self {
            case .entry(let x): "e\(x.persistentModelID.hashValue)"
            case .failure(let x): "f\(x.persistentModelID.hashValue)"
            case .week(let x): "w\(x.persistentModelID.hashValue)"
            case .letter(let x): "l\(x.persistentModelID.hashValue)"
            }
        }

        var date: Date {
            switch self {
            case .entry(let x): x.day
            case .failure(let x): x.date
            case .week(let x): x.weekStart.addingDays(6)
            case .letter(let x): x.writtenAt
            }
        }

        /// All the text, for searching.
        var text: String {
            switch self {
            case .entry(let x): ([x.question] + x.texts).joined(separator: " ")
            case .failure(let x): [x.taskTitle, x.reason.title, x.critique, x.prevention].joined(separator: " ")
            case .week(let x): x.text
            case .letter(let x): x.text
            }
        }
    }

    private var items: [Item] {
        var all: [Item] = []
        if filter == .all || filter == .days { all += entries.filter(\.hasWriting).map(Item.entry) }
        if filter == .all || filter == .failures { all += failures.map(Item.failure) }
        if filter == .all || filter == .weeks { all += reflections.filter { !$0.text.isEmpty }.map(Item.week) }
        // A letter belongs to the archive only once it may be read.
        if filter == .all { all += letters.filter { $0.openedAt != nil }.map(Item.letter) }
        let key = search.activityKey
        return all
            .filter { key.isEmpty || $0.text.activityKey.contains(key) }
            .sorted { $0.date > $1.date }
    }

    private var months: [(month: Date, items: [Item])] {
        let grouped = Dictionary(grouping: items) { Calendar.app.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                Picker("Co zobrazit", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if months.isEmpty {
                    Text(search.isEmpty ? "Zatím tu nic není. První zápis přidáš na obrazovce Deník." : "Nic takového jsi nenapsal.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .card()
                }
                ForEach(months, id: \.month) { group in
                    Text(group.month.formatted(Date.FormatStyle(locale: .app).month(.wide).year()).capitalizedFirst)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 8)
                    ForEach(group.items) { item in
                        switch item {
                        case .entry(let entry): DiaryEntryCard(entry: entry)
                        case .failure(let record): FailureNoteCard(record: record)
                        case .week(let reflection): weekCard(reflection)
                        case .letter(let letter): letterCard(letter)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .searchable(text: $search, prompt: "Hledat v zápisech")
        .screenBackground()
        .navigationTitle("Všechny zápisy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func weekCard(_ reflection: WeekReflection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SEBEREFLEXE · TÝDEN \(reflection.weekStart.weekNumber)").labelStyle(Theme.textPrimary)
                Spacer()
                Text(reflection.satisfactionLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            DiaryQuote(label: "Jak jsem se sebou spokojený", text: reflection.text)
        }
        .card()
    }

    private func letterCard(_ letter: FutureLetter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("DOPIS BUDOUCÍMU JÁ · \(letter.writtenAt.dayMonthText)", systemImage: "envelope.open")
                .labelStyle(Theme.green)
            Text(letter.text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}

// MARK: Shared diary cards

struct DiaryQuote: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textTertiary)
            Text("„\(text)“")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One day of the diary as it is read back.
struct DiaryEntryCard: View {
    let entry: DiaryEntry

    static func lines(of entry: DiaryEntry) -> [(label: String, text: String)] {
        [(entry.question, entry.answer), ("Povedlo se", entry.wentWell), ("Nepovedlo se", entry.wentBadly),
         ("Zítra jinak", entry.doDifferently), ("Vděčnost", entry.gratitude)]
            .filter { !$0.1.isEmpty }
            .map { (label: $0.0, text: $0.1) }
    }

    static func levelColor(_ level: Int) -> Color {
        level <= 2 ? Theme.red : (level == 3 ? Theme.orange : Theme.green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.day.longDayText.uppercased()).labelStyle()
                Spacer()
                if entry.mood > 0 { Badge(text: "Nálada \(entry.mood)", color: Self.levelColor(entry.mood)) }
                if entry.energy > 0 { Badge(text: "Energie \(entry.energy)", color: Self.levelColor(entry.energy)) }
            }
            ForEach(Self.lines(of: entry), id: \.label) { line in
                DiaryQuote(label: line.label, text: line.text)
            }
        }
        .card()
    }
}

/// What was written in "Nesplnil jsem", read back next to the rest of the reflection.
struct FailureNoteCard: View {
    let record: FailureRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(record.kind == .missed ? "NESPLNĚNO" : "PŘESKOČENO") · \(record.taskDate.dayMonthText)")
                .labelStyle(Theme.red)
            Text(record.taskTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            DiaryQuote(label: record.reason.title, text: record.critique)
            if !record.prevention.isEmpty {
                DiaryQuote(label: "Příště", text: record.prevention)
            }
        }
        .card()
    }
}
