import SwiftUI
import SwiftData

/// The self-reflection diary: today's short entry, a look back at older ones, letters to the future self
/// and everything written about failures, in one place.
struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DiaryEntry.day, order: .reverse) private var entries: [DiaryEntry]
    @Query(sort: \FutureLetter.opensAt) private var letters: [FutureLetter]
    @Query(sort: \FailureRecord.date, order: .reverse) private var failures: [FailureRecord]
    @Query(sort: \WeekReflection.weekStart, order: .reverse) private var reflections: [WeekReflection]
    @Query private var settingsList: [UserSettings]
    @ObservedObject private var dictation = Dictation.shared

    /// True when shown inside another screen's navigation (opened from Settings) instead of as a tab.
    var isEmbedded = false

    @State private var draft = Draft()
    @State private var loadedDay: Date?
    @State private var writesLetter = false
    @State private var openLetter: FutureLetter?
    @State private var pointsGain: PointsGain?
    @State private var savedAt: Date?

    private static let historyDays = 30
    private static let scale = 1...5

    private var settings: UserSettings? { settingsList.first }
    private var voice: Bool { settings?.diaryVoiceEnabled == true }

    struct Draft: Equatable {
        var answer = ""
        var wentWell = ""
        var wentBadly = ""
        var doDifferently = ""
        var gratitude = ""
        var mood = 0
        var energy = 0
    }

    var body: some View {
        Group {
            if isEmbedded {
                content
            } else {
                NavigationStack { content }
            }
        }
        .diaryLock(settings?.diaryLockEnabled == true)
    }

    private var content: some View {
        let now = Date.now
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                header(now: now)
                todayCard(now: now)
                if let lookBack = DiaryService.lookBack(entries, now: now) {
                    lookBackCard(lookBack.label, lookBack.entry)
                }
                letterCard(now: now)
                NavigationLink { DiaryArchiveView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("VŠECHNY ZÁPISY").labelStyle(Theme.textPrimary)
                            Text("Dny, selhání, týdny i dopisy. Podle měsíců, s hledáním.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Text("\(entries.filter(\.hasWriting).count)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                    }
                    .card()
                }
                NavigationLink { JournalView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SEBEREFLEXE TÝDNE").labelStyle(Theme.textPrimary)
                            Text(reflections.isEmpty ? "První vznikne v neděli večer" : "Zápisy: \(reflections.count)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                    }
                    .card()
                }
                history(now: now)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear { load(now: .now) }
        .onDisappear { dictation.stop() }
        .sheet(isPresented: $writesLetter) { FutureLetterEditor() }
        .sheet(item: $openLetter) { FutureLetterReader(letter: $0) }
        .alert("Diktování", isPresented: Binding(get: { dictation.errorMessage != nil },
                                                 set: { if !$0 { dictation.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dictation.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let pointsGain {
                PointsGainToast(amount: pointsGain.amount) { self.pointsGain = nil }
                    .id(pointsGain.id)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.success, trigger: pointsGain?.id) { _, new in new != nil }
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        let streak = DiaryService.streak(entries, now: now)
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DENÍK").labelStyle()
                Text(now.longDayText)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 26))
                Text("\(streak)")
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(streak > 0 ? Theme.orange : Theme.textTertiary)
            .accessibilityLabel("Série psaní: \(String.days(streak))")
        }
    }

    // MARK: Today

    private func todayCard(now: Date) -> some View {
        let existing = DiaryService.entry(on: now, in: entries)
        let draftHasWriting = [draft.answer, draft.wentWell, draft.wentBadly, draft.doDifferently, draft.gratitude]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // Points only for something written, not for mood and energy alone.
        let earnsPoints = existing?.hasWriting != true && draftHasWriting
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("OTÁZKA DNE").labelStyle(Theme.orange)
                Text(existing?.question ?? DiaryService.question(for: now))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                field("answer", "Stačí jedna věta.", text: $draft.answer, lines: 2...6)
            }
            scaleRow("NÁLADA", value: $draft.mood, low: "mizerně", high: "skvěle")
            scaleRow("ENERGIE", value: $draft.energy, low: "vyčerpaný", high: "nabitý")
            VStack(alignment: .leading, spacing: 10) {
                Text("TŘI ŘÁDKY").labelStyle()
                field("well", "Co se povedlo", text: $draft.wentWell, lines: 1...4, symbol: "checkmark", color: Theme.green)
                field("badly", "Co se nepovedlo", text: $draft.wentBadly, lines: 1...4, symbol: "xmark", color: Theme.red)
                field("differently", "Co zítra udělám jinak", text: $draft.doDifferently, lines: 1...4,
                      symbol: "arrow.forward", color: Theme.orange)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("VDĚČNOST").labelStyle()
                field("gratitude", "Za co jsem dnes vděčný", text: $draft.gratitude, lines: 1...3, symbol: "heart", color: Theme.textSecondary)
            }
            Button(earnsPoints ? "ULOŽIT ZÁPIS · +\(DiaryService.pointsPerEntry) BODŮ" : "ULOŽIT ZMĚNY") { save(now: .now) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(draft == stored(existing))
            if let savedAt, draft == stored(existing) {
                Text("Uloženo v \(savedAt.timeText)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .card()
    }

    private func field(_ id: String, _ placeholder: String, text: Binding<String>, lines: ClosedRange<Int>,
                       symbol: String? = nil, color: Color = Theme.textSecondary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 18)
                    .padding(.top, 13)
            }
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(lines)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .padding(10)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if voice {
                DictationButton(field: id, text: text)
                    .padding(.top, 4)
            }
        }
    }

    private func scaleRow(_ title: String, value: Binding<Int>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).labelStyle()
                Spacer()
                Text(value.wrappedValue == 0 ? "" : (value.wrappedValue <= 2 ? low : (value.wrappedValue >= 4 ? high : "tak napůl")))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                ForEach(Array(Self.scale), id: \.self) { level in
                    let isSelected = value.wrappedValue == level
                    Button {
                        // Tapping the chosen level again clears it.
                        value.wrappedValue = isSelected ? 0 : level
                    } label: {
                        Text("\(level)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSelected ? Theme.onPrimary : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Self.levelColor(level) : Theme.cardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private static func levelColor(_ level: Int) -> Color {
        level <= 2 ? Theme.red : (level == 3 ? Theme.orange : Theme.green)
    }

    private func stored(_ entry: DiaryEntry?) -> Draft {
        guard let entry else { return Draft() }
        return Draft(answer: entry.answer, wentWell: entry.wentWell, wentBadly: entry.wentBadly,
                     doDifferently: entry.doDifferently, gratitude: entry.gratitude, mood: entry.mood, energy: entry.energy)
    }

    private func load(now: Date) {
        guard loadedDay != now.startOfDay else { return }
        loadedDay = now.startOfDay
        draft = stored(DiaryService.entry(on: now, in: entries))
    }

    private func save(now: Date) {
        dictation.stop()
        let entry: DiaryEntry
        if let existing = DiaryService.entry(on: now, in: entries) {
            entry = existing
        } else {
            entry = DiaryEntry(day: now, question: DiaryService.question(for: now), now: now)
            context.insert(entry)
        }
        let wasWritten = entry.hasWriting
        entry.answer = draft.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.wentWell = draft.wentWell.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.wentBadly = draft.wentBadly.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.doDifferently = draft.doDifferently.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.gratitude = draft.gratitude.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.mood = draft.mood
        entry.energy = draft.energy
        entry.updatedAt = now
        // The points belong to the moment something was first written, not to the empty entry's creation.
        if !wasWritten, entry.hasWriting {
            entry.createdAt = now
            pointsGain = PointsGain(amount: DiaryService.pointsPerEntry)
        }
        try? context.save()
        draft = stored(entry)
        savedAt = now
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: Look back

    private func lookBackCard(_ label: String, _ entry: DiaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: "clock.arrow.circlepath").labelStyle(Theme.textPrimary)
            Text(entry.day.longDayText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            ForEach(lines(of: entry), id: \.label) { line in
                quote(line.label, line.text)
            }
        }
        .card()
    }

    private func lines(of entry: DiaryEntry) -> [(label: String, text: String)] {
        [(entry.question, entry.answer), ("Povedlo se", entry.wentWell), ("Nepovedlo se", entry.wentBadly),
         ("Zítra jinak", entry.doDifferently), ("Vděčnost", entry.gratitude)]
            .filter { !$0.1.isEmpty }
            .map { (label: $0.0, text: $0.1) }
    }

    private func quote(_ label: String, _ text: String) -> some View {
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

    // MARK: Letters

    @ViewBuilder
    private func letterCard(now: Date) -> some View {
        let due = letters.first { $0.isDue(now) && $0.openedAt == nil }
        let waiting = letters.first { !$0.isDue(now) }
        VStack(alignment: .leading, spacing: 10) {
            Label("DOPIS BUDOUCÍMU JÁ", systemImage: due != nil ? "envelope.open.fill" : "envelope.fill")
                .labelStyle(due != nil ? Theme.green : Theme.textPrimary)
            if let due {
                Text("Napsal sis ho \(due.writtenAt.longDayText). Teď si ho můžeš přečíst.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                Button("OTEVŘÍT DOPIS") { openLetter = due }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.green))
            } else if let waiting {
                Text("Zapečetěný dopis se otevře \(waiting.opensAt.longDayText). Do té doby ho nepřečteš.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Napiš si, kde chceš být za měsíc a co si teď slibuješ. Otevřít ho půjde až za \(DiaryService.letterDelayDays) dní.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("NAPSAT DOPIS") { writesLetter = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            let opened = letters.filter { $0.openedAt != nil }
            if !opened.isEmpty {
                ForEach(opened.sorted { $0.writtenAt > $1.writtenAt }) { letter in
                    Button { openLetter = letter } label: {
                        HStack {
                            Text("Dopis z \(letter.writtenAt.dayMonthText)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .card()
    }

    // MARK: History

    private enum Item: Identifiable {
        case entry(DiaryEntry)
        case failure(FailureRecord)

        var id: String {
            switch self {
            case .entry(let entry): "e\(entry.persistentModelID.hashValue)"
            case .failure(let record): "f\(record.persistentModelID.hashValue)"
            }
        }

        var date: Date {
            switch self {
            case .entry(let entry): entry.day
            case .failure(let record): record.date
            }
        }
    }

    @ViewBuilder
    private func history(now: Date) -> some View {
        let since = now.startOfDay.addingDays(-Self.historyDays)
        let items = (entries.filter { $0.day >= since && $0.hasWriting && !$0.day.isSameDay(as: now) }.map(Item.entry)
                     + failures.filter { $0.date >= since }.map(Item.failure))
            .sorted { $0.date > $1.date }
        if !items.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(text: "Posledních \(Self.historyDays) dní · starší ve Všech zápisech")
                ForEach(items) { item in
                    switch item {
                    case .entry(let entry): DiaryEntryCard(entry: entry)
                    case .failure(let record): FailureNoteCard(record: record)
                    }
                }
            }
        }
    }
}

/// Writing a letter that stays sealed for a month.
private struct FutureLetterEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [UserSettings]
    @State private var text = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DOPIS BUDOUCÍMU JÁ").labelStyle(Theme.textPrimary)
            Text("Otevře se \(Date.now.addingDays(DiaryService.letterDelayDays).longDayText). Do té doby ho neuvidíš.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            HStack(alignment: .top, spacing: 8) {
                TextField("Kde chceš být za měsíc? Co si teď slibuješ? Co by sis měl připomenout?", text: $text, axis: .vertical)
                    .lineLimit(8...20)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .card()
                if settingsList.first?.diaryVoiceEnabled == true {
                    DictationButton(field: "letter", text: $text)
                }
            }
            Spacer()
            Button("ZAPEČETIT DOPIS") {
                Dictation.shared.stop()
                context.insert(FutureLetter(text: trimmed, opensAt: Date.now.addingDays(DiaryService.letterDelayDays)))
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmed.isEmpty)
            Button("ZRUŠIT") {
                Dictation.shared.stop()
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.screenPadding)
        .padding(.top, 12)
        .screenBackground()
        .appAppearance()
    }
}

private struct FutureLetterReader: View {
    @Environment(\.dismiss) private var dismiss
    let letter: FutureLetter

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("DOPIS Z \(letter.writtenAt.dayMonthText)", systemImage: "envelope.open.fill").labelStyle(Theme.green)
            ScrollView {
                Text(letter.text)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("ZAVŘÍT") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding(Theme.screenPadding)
        .padding(.top, 12)
        .screenBackground()
        .appAppearance()
        .onAppear {
            if letter.openedAt == nil { letter.openedAt = .now }
        }
    }
}
