import SwiftUI
import SwiftData

/// Evening close of the day: the open promises one by one, each answered with a single tap.
/// "Ještě to dnes stihnu" puts a promise aside without closing it, so the day is only called
/// closed when nothing that could still be done is left.
struct RealityCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskItem]
    @Query private var diaryEntries: [DiaryEntry]
    @State private var excuse: ExcuseRequest?
    @State private var workoutTask: TaskItem?
    @State private var proofTask: TaskItem?
    /// Promises the user said they will still manage today.
    @State private var later: Set<PersistentIdentifier> = []
    @State private var diaryLine = ""
    @State private var diaryLoaded = false
    @FocusState private var diaryFocused: Bool

    private var today: [TaskItem] {
        tasks.filter { !$0.isRemoved && $0.scheduledDate.isSameDay(as: .now) }
    }
    private var pending: [TaskItem] {
        today.filter { $0.status == .pending }.sorted { $0.priority.rank > $1.priority.rank }
    }
    /// Still to be answered now.
    private var queue: [TaskItem] { pending.filter { !later.contains($0.persistentModelID) } }
    /// Put aside for later today.
    private var deferred: [TaskItem] { pending.filter { later.contains($0.persistentModelID) } }
    private var kept: Int { today.filter(\.isDone).count }

    private enum Phase { case asking, waiting, closed }
    private var phase: Phase {
        if !queue.isEmpty { return .asking }
        return deferred.isEmpty ? .closed : .waiting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            switch phase {
            case .asking: asking
            case .waiting: waiting
            case .closed: closed
            }
        }
        .screenBackground()
        .appAppearance()
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: queue.map(\.persistentModelID))
        .animation(.easeInOut(duration: 0.3), value: later)
        .fullScreenCover(item: $excuse) { NoExcusesView(task: $0.task, kind: $0.kind) }
        .sheet(item: $workoutTask) { WorkoutLogView(task: $0) }
        .sheet(item: $proofTask) { ProofView(task: $0) }
        .onAppear(perform: loadDiary)
    }

    // MARK: Header

    private var topBar: some View {
        HStack {
            Text("VEČER · \(Date.now.weekdayText) \(Date.now.timeText)")
                .labelStyle(Theme.orange)
                .textCase(.uppercase)
            Spacer()
            Button("Zavřít") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 24)
    }

    private func heading(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
            progress
                .padding(.top, 10)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
    }

    /// One bar per promise: green kept, red lost, orange put aside, white the one being asked.
    private var progress: some View {
        let current = queue.first?.persistentModelID
        return HStack(spacing: 6) {
            ForEach(today.sorted { $0.dueDate < $1.dueDate }) { task in
                Capsule()
                    .fill(color(for: task, current: current))
                    .frame(height: 5)
            }
        }
    }

    private func color(for task: TaskItem, current: PersistentIdentifier?) -> Color {
        if task.isDone { return Theme.green }
        if task.status != .pending { return Theme.red }
        if later.contains(task.persistentModelID) { return Theme.orange }
        return task.persistentModelID == current ? Theme.textPrimary : Theme.cardRaised
    }

    // MARK: Asking

    private var asking: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Uzavři dnešek", "Jedním klepnutím. Buď k sobě upřímný.")
            ZStack {
                ForEach(Array(queue.prefix(3).enumerated()).reversed(), id: \.element.persistentModelID) { index, task in
                    card(task)
                        .scaleEffect(1 - CGFloat(index) * 0.05, anchor: .top)
                        .offset(y: CGFloat(index) * 14)
                        .opacity(1 - Double(index) * 0.25)
                        .zIndex(Double(-index))
                        .allowsHitTesting(index == 0)
                        .transition(.asymmetric(insertion: .identity,
                                                removal: .offset(x: -420).combined(with: .opacity)))
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 28)
            Spacer(minLength: 12)
            if let current = queue.first {
                actions(for: current)
            }
        }
    }

    private func card(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: task.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 52, height: 52)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(task.title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 8)
            Text(metadata(of: task))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Text("Podvedl bys jen sám sebe.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300, alignment: .topLeading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1))
    }

    private func metadata(of task: TaskItem) -> String {
        var parts = [task.category.title, "\(task.plannedMinutes) min"]
        if let deadline = task.deadline { parts.append("do \(deadline.timeText)") }
        return parts.joined(separator: " · ")
    }

    private func actions(for task: TaskItem) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button("NESPLNIL JSEM") { miss(task) }
                    .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                Button("SPLNIL JSEM") { finish(task) }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.green))
            }
            Button("Ještě to dnes stihnu") { putAside(task) }
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 24)
    }

    // MARK: Waiting

    /// Everything left was put aside: the day is not over for those promises.
    private var waiting: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Ještě to dnes stihneš.", "Tyhle sliby ještě nejsou uzavřené. Máš čas je dodržet.")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(deferred) { task in
                    HStack(spacing: 12) {
                        Image(systemName: task.icon)
                            .frame(width: 24)
                            .foregroundStyle(Theme.orange)
                        Text(task.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 24)
            Spacer()
            VStack(spacing: 6) {
                Button("ZPĚT NA DNEŠEK") { dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Projít je znovu") { later.removeAll() }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: 40)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
    }

    // MARK: Closed

    private var closed: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 12) {
                DrawnCheck(isRecent: true, size: 64)
                    .frame(width: 64, height: 64)
                Text(today.isEmpty ? "Dnes bez slibů." : "DEN UZAVŘEN")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                if !today.isEmpty {
                    Text(kept == today.count ? "Dodrženo: \(kept) z \(today.count). Takhle vypadá dodržené slovo."
                                             : "Dodrženo: \(kept) z \(today.count). Zbytek je zavřený čestně, a to se počítá.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                TextField("Jedna věta do deníku: co ti dnes šlo?", text: $diaryLine, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(1...4)
                    .focused($diaryFocused)
                    .padding(14)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.border, lineWidth: 1))
            .padding(.horizontal, Theme.screenPadding)
            Spacer()
            Button("ULOŽIT A DOBROU NOC") { saveAndClose() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
        }
        .onAppear { Haptics.success() }
    }

    // MARK: Actions

    private func finish(_ task: TaskItem) {
        task.completionShare = 1
        task.partialNote = ""
        if task.category == .gym {
            workoutTask = task
        } else if task.requiresProof {
            proofTask = task
        } else {
            Haptics.medium()
            withAnimation { task.markDone() }
            try? context.save()
        }
    }

    private func miss(_ task: TaskItem) {
        excuse = ExcuseRequest(task: task, kind: .missed)
    }

    private func putAside(_ task: TaskItem) {
        Haptics.light()
        later.insert(task.persistentModelID)
    }

    // MARK: Diary

    private func loadDiary() {
        guard !diaryLoaded else { return }
        diaryLoaded = true
        diaryLine = DiaryService.entry(on: .now, in: diaryEntries)?.answer ?? ""
    }

    /// One line is enough to count as today's entry; an empty line writes nothing.
    private func saveAndClose() {
        let text = diaryLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let entry: DiaryEntry
            if let existing = DiaryService.entry(on: .now, in: diaryEntries) {
                entry = existing
            } else {
                entry = DiaryEntry(day: .now, question: DiaryService.question(for: .now))
                context.insert(entry)
            }
            if !entry.hasWriting { entry.createdAt = .now }
            entry.answer = text
            entry.updatedAt = .now
            try? context.save()
        }
        dismiss()
    }
}
