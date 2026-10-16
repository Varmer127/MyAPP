import SwiftUI

/// The exercise library: search, filter by muscle or equipment, add your own.
struct ExerciseLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    /// The user's own exercise names, shown with the built-in ones.
    let own: [String]
    let onPick: (String) -> Void
    @State private var search = ""
    @State private var muscle: Muscle?
    @State private var equipment: Equipment?
    @State private var detail: CatalogExercise?

    private var matches: [CatalogExercise] {
        let key = search.activityKey
        return ExerciseCatalog.all.filter { exercise in
            (key.isEmpty || exercise.name.activityKey.contains(key))
                && (muscle.map { exercise.muscles.contains($0) } ?? true)
                && (equipment.map { exercise.equipment == $0 } ?? true)
        }
    }

    private var ownMatches: [String] {
        let key = search.activityKey
        return own.filter { name in ExerciseCatalog.named(name) == nil && (key.isEmpty || name.activityKey.contains(key)) }
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
                if !typed.isEmpty, ExerciseCatalog.named(typed) == nil, !own.contains(where: { $0.activityKey == typed.activityKey }) {
                    Section {
                        Button {
                            pick(typed)
                        } label: {
                            Label("Přidat vlastní cvik „\(typed)“", systemImage: "plus.circle.fill")
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                if muscle == nil, equipment == nil, !ownMatches.isEmpty {
                    Section("Vlastní") {
                        ForEach(ownMatches, id: \.self) { name in
                            Button { pick(name) } label: {
                                Text(name).foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                Section("Knihovna · \(matches.count)") {
                    ForEach(matches) { exercise in
                        HStack(spacing: 12) {
                            Button { pick(exercise.name) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("\(exercise.primary.map(\.title).joined(separator: ", ")) · \(exercise.equipment.title)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button { detail = exercise } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Jak na \(exercise.name)")
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Hledat cvik")
            .navigationTitle("Přidat cvik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }
                }
            }
            .sheet(item: $detail) { exercise in
                ExerciseDetailView(exercise: exercise) {
                    detail = nil
                    pick(exercise.name)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .appAppearance()
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
                .font(.system(size: 13, weight: .semibold))
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
        onPick(name)
        dismiss()
    }
}

/// How to do an exercise and what it works, with the muscles lit on the body map.
struct ExerciseDetailView: View {
    let exercise: CatalogExercise
    let onAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(exercise.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(exercise.equipment.title.uppercased()).labelStyle()
                MuscleMapView(intensity: Dictionary(uniqueKeysWithValues:
                    exercise.primary.map { ($0, 1.0) } + exercise.secondary.filter { !exercise.primary.contains($0) }.map { ($0, 0.45) }))
                    .frame(height: 230)
                VStack(alignment: .leading, spacing: 6) {
                    Text("HLAVNĚ: \(exercise.primary.map(\.title).joined(separator: ", "))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if !exercise.secondary.isEmpty {
                        Text("POMÁHAJÍ: \(exercise.secondary.map(\.title).joined(separator: ", "))")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Text(exercise.tip)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("PŘIDAT DO TRÉNINKU", action: onAdd)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Theme.screenPadding)
            .padding(.top, 8)
        }
        .screenBackground()
        .appAppearance()
    }
}
