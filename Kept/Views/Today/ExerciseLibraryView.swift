import SwiftData
import SwiftUI

/// The exercise library: search, filter by muscle or equipment, last workout's exercises, own exercises with photos.
/// Every row has a small picture and an (i) with the technique.
struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    /// Older own exercises that are only a name (from before own exercises had details).
    let own: [String]
    let onPick: (String) -> Void
    @State private var search = ""
    @State private var muscle: Muscle?
    @State private var equipment: Equipment?
    @State private var detail: String?
    @State private var creating: String?
    @Query private var logs: [ExerciseLog]
    private let store = CustomExerciseStore.shared

    private static let favouriteCount = 3
    private static let recentDays = 60

    /// The user's most used exercises for the chosen muscle group, recent use first; none without a chosen group.
    private var favourites: [CatalogExercise] {
        guard let muscle, search.isEmpty else { return [] }
        return ExerciseUsage.top(Self.favouriteCount, for: muscle, in: logs, recentDays: Self.recentDays)
            .filter { exercise in equipment.map { exercise.equipment == $0 } ?? true }
    }

    /// The exercises of the last workout before today, in the order they were done.
    private var lastWorkout: (title: String, names: [String])? {
        let today = Date.now.startOfDay
        guard let latest = logs.filter({ $0.date < today && $0.task != nil }).max(by: { $0.date < $1.date }),
              let task = latest.task else { return nil }
        var seen = Set<String>()
        let names = task.exercises.sorted { $0.date < $1.date }.map(\.name).filter { seen.insert($0.activityKey).inserted }
        guard !names.isEmpty else { return nil }
        let type = task.workoutType.isEmpty ? String(localized: "Trénink") : task.workoutType
        return ("\(type) · \(latest.date.dayMonthText)", names)
    }

    private var matches: [CatalogExercise] {
        let shown = Set(favourites.map(\.name))
        return ExerciseCatalog.all.filter { exercise in
            !shown.contains(exercise.name)
                && ExerciseSearch.matches(search, in: [exercise.name, exercise.english])
                && (muscle.map { exercise.muscles.contains($0) } ?? true)
                && (equipment.map { exercise.equipment == $0 } ?? true)
        }
    }

    private var customMatches: [CustomExercise] {
        store.exercises.filter { exercise in
            ExerciseSearch.matches(search, in: [exercise.name])
                && (muscle.map { exercise.primary.contains($0) } ?? true)
                && (equipment.map { exercise.equipment == $0 } ?? true)
        }
        .sorted { $0.name < $1.name }
    }

    private var ownMatches: [String] {
        // Old own exercises are only a name without a photo: they show up when searched for, not in the list.
        guard !ExerciseSearch.normalized(search).isEmpty else { return [] }
        return own.filter { name in
            ExerciseCatalog.named(name) == nil && store.named(name) == nil && ExerciseSearch.matches(search, in: [name])
        }
    }

    private var typed: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filters
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                Section {
                    Button {
                        Haptics.light()
                        creating = typed
                    } label: {
                        Label(typed.isEmpty || ExerciseCatalog.named(typed) != nil || store.named(typed) != nil
                              ? "Vytvořit vlastní cvik s fotkou" : "Vytvořit vlastní cvik „\(typed)“",
                              systemImage: "plus.circle.fill")
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
                .listRowBackground(Theme.card)
                if search.isEmpty, muscle == nil, equipment == nil, let lastWorkout {
                    Section {
                        ForEach(Array(lastWorkout.names.enumerated()), id: \.offset) { _, name in row(name) }
                    } header: {
                        Label("Z minulého tréninku · \(lastWorkout.title)", systemImage: "clock.arrow.circlepath")
                    }
                    .listRowBackground(Theme.card)
                }
                if !customMatches.isEmpty || !ownMatches.isEmpty {
                    Section("Vlastní") {
                        ForEach(customMatches) { exercise in row(exercise.name) }
                        ForEach(ownMatches, id: \.self) { name in row(name) }
                    }
                    .listRowBackground(Theme.card)
                }
                if let muscle, !favourites.isEmpty {
                    Section("Nejčastěji · \(muscle.title)") {
                        ForEach(favourites) { exercise in row(exercise.name) }
                    }
                    .listRowBackground(Theme.card)
                }
                Section("Knihovna · \(matches.count)") {
                    ForEach(matches) { exercise in row(exercise.name) }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Název cviku")
            .navigationTitle("Přidat cvik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }
                }
            }
            .sheet(item: Binding(get: { detail.map(NameBox.init) }, set: { detail = $0?.name })) { box in
                ExerciseDetailView(name: box.name) {
                    detail = nil
                    pick(box.name)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: Binding(get: { creating.map(NameBox.init) }, set: { creating = $0?.name })) { box in
                CustomExerciseEditor(name: box.name) { name in
                    creating = nil
                    pick(name)
                }
            }
        }
        .appAppearance()
    }

    /// One exercise: small picture, name and muscles; touching it adds it, the (i) shows how to do it.
    private func row(_ name: String) -> some View {
        let info = ExerciseInfo(name)
        return HStack(spacing: 12) {
            Button { pick(name) } label: {
                HStack(spacing: 12) {
                    ExerciseThumb(name: name, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                        // Found by its English name: that name is shown, so it is clear why it is in the list.
                        let english = search.isEmpty ? nil : info.catalog?.englishMatch(for: search)
                        let meta = [english ?? info.muscleLine, info.equipment?.title ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
                        if !meta.isEmpty {
                            Text(meta)
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PillPressStyle())
            Button {
                Haptics.light()
                detail = name
            } label: {
                Image(systemName: "info.circle")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PillPressStyle())
            .accessibilityLabel("Jak na \(name)")
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("Všechny partie", isOn: muscle == nil) { muscle = nil }
                    ForEach(Muscle.allCases) { item in
                        chip(item.title, isOn: muscle == item) { muscle = muscle == item ? nil : item }
                    }
                }
                .padding(.horizontal, 4)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip("Jakékoli vybavení", isOn: equipment == nil) { equipment = nil }
                    ForEach(Equipment.allCases) { item in
                        chip(item.title, isOn: equipment == item) { equipment = equipment == item ? nil : item }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .scaledFont(.caption, weight: .semibold)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .background(isOn ? Theme.textPrimary : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func pick(_ name: String) {
        Haptics.success()
        onPick(name)
        dismiss()
    }
}

private struct NameBox: Identifiable {
    let name: String
    var id: String { name }
}
