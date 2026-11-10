import PhotosUI
import SwiftUI

/// A small square picture of an exercise: the user's photo for their own exercises,
/// otherwise a symbol of the equipment on a tile tinted by the muscle group.
struct ExerciseThumb: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        let info = ExerciseInfo(name)
        let photo = info.catalog.flatMap { ExercisePhoto.image($0.photo, frame: 0) }
            ?? info.custom.flatMap { CustomExerciseStore.shared.photo(of: $0) }
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Self.tint(info.primary.first).opacity(0.18)
                Image(systemName: Self.symbol(info.equipment))
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(Self.tint(info.primary.first))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
        .overlay(RoundedRectangle(cornerRadius: size * 0.26).stroke(Theme.border, lineWidth: 1))
        .accessibilityHidden(true)
    }

    static func symbol(_ equipment: Equipment?) -> String {
        switch equipment {
        case .barbell: "figure.strengthtraining.traditional"
        case .dumbbell: "dumbbell.fill"
        case .machine: "figure.strengthtraining.functional"
        case .cable: "figure.cross.training"
        case .bodyweight: "figure.core.training"
        case .kettlebell: "figure.highintensity.intervaltraining"
        case .band: "figure.flexibility"
        case .other, .none: "figure.mixed.cardio"
        }
    }

    /// Pushing muscles warm, pulling cool, legs green, core violet.
    static func tint(_ muscle: Muscle?) -> Color {
        switch muscle {
        case .chest, .shoulders, .triceps: Theme.orange
        case .lats, .upperBack, .lowerBack, .traps, .biceps, .forearms: Color(hex: 0x0A84FF)
        case .glutes, .quads, .hamstrings, .adductors, .calves: Theme.green
        case .abs, .obliques: Color(hex: 0xBF5AF2)
        case .none: Theme.textSecondary
        }
    }
}

/// The photos of the built-in exercises, bundled with the app. From free-exercise-db (public domain).
enum ExercisePhoto {
    static func image(_ photo: String, frame: Int) -> UIImage? {
        let file = "ex-\(photo)-\(frame)"
        if let image = UIImage(named: "\(file).jpg") { return image }
        guard let url = Bundle.main.url(forResource: file, withExtension: "jpg")
                ?? Bundle.main.url(forResource: file, withExtension: "jpg", subdirectory: "ExercisePhotos") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

/// The start and the end of the movement, taking turns, so the technique is seen moving. Touching it pauses.
struct ExerciseMotionPhotos: View {
    let photo: String
    @State private var frame = 0
    @State private var isPaused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let interval: Duration = .milliseconds(1100)

    var body: some View {
        let first = ExercisePhoto.image(photo, frame: 0)
        let second = ExercisePhoto.image(photo, frame: 1)
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let first { Image(uiImage: first).resizable().scaledToFit().opacity(frame == 0 || second == nil ? 1 : 0) }
                if let second { Image(uiImage: second).resizable().scaledToFit().opacity(frame == 1 ? 1 : 0) }
            }
            .animation(.easeInOut(duration: 0.35), value: frame)
            if second != nil {
                HStack(spacing: 6) {
                    Text(frame == 0 ? "Začátek" : "Konec")
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                }
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.light()
            isPaused.toggle()
        }
        .task(id: isPaused) {
            guard second != nil, !isPaused, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                if Task.isCancelled { break }
                frame = 1 - frame
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fotky cviku, začátek a konec pohybu")
    }
}

/// The (i) next to an exercise: opens how to do it.
struct ExerciseInfoButton: View {
    let name: String
    @State private var isOpen = false

    var body: some View {
        Button {
            Haptics.light()
            isOpen = true
        } label: {
            Image(systemName: "info.circle")
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(PillPressStyle())
        .accessibilityLabel("Jak na \(name)")
        .sheet(isPresented: $isOpen) {
            ExerciseDetailView(name: name, onAdd: nil)
                .presentationDetents([.medium, .large])
        }
    }
}

/// Only the springy press, for icon buttons.
struct PillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(PressBounce(isPressed: configuration.isPressed))
    }
}

/// How to do an exercise: what it works on the body map, the steps in order and the usual mistakes.
/// The user's own exercises show their photo and their own notes, and can be edited here.
struct ExerciseDetailView: View {
    let name: String
    let onAdd: (() -> Void)?
    @State private var shown = false
    @State private var editing: CustomExercise?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let info = ExerciseInfo(name)
        let technique = ExerciseTechnique.of(name)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ExerciseThumb(name: name, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .scaledFont(.title, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let equipment = info.equipment {
                            Text(equipment.title.uppercased()).labelStyle()
                        }
                    }
                }
                if let catalog = info.catalog {
                    ExerciseMotionPhotos(photo: catalog.photo)
                }
                if let custom = info.custom, let photo = CustomExerciseStore.shared.photo(of: custom) {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                }
                if !info.primary.isEmpty || info.catalog != nil {
                    MuscleMapView(intensity: muscleIntensity(info))
                        .frame(height: 200)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HLAVNĚ: \(info.muscleLine)")
                            .scaledFont(.caption, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                        if let secondary = info.catalog?.secondary, !secondary.isEmpty {
                            Text("POMÁHAJÍ: \(secondary.map(\.title).joined(separator: ", "))")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                if let technique {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("JAK NA TO").labelStyle()
                        ForEach(Array(technique.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .scaledFont(.caption, weight: .heavy)
                                    .foregroundStyle(Theme.onPrimary)
                                    .frame(width: 26, height: 26)
                                    .background(Theme.textPrimary, in: Circle())
                                Text(step)
                                    .scaledFont(.body)
                                    .foregroundStyle(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .opacity(shown ? 1 : 0)
                            .offset(y: shown ? 0 : 10)
                            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.08), value: shown)
                        }
                    }
                    .card()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ČASTÉ CHYBY").labelStyle(Theme.orange)
                        ForEach(technique.mistakes, id: \.self) { mistake in
                            Label {
                                Text(mistake).fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.red)
                            }
                            .scaledFont(.body)
                            .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .card()
                }
                if let tip = info.catalog?.tip {
                    Label(tip, systemImage: "lightbulb.fill")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let custom = info.custom {
                    if !custom.technique.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TVOJE POZNÁMKY K TECHNICE").labelStyle()
                            Text(custom.technique)
                                .scaledFont(.body)
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .card()
                    }
                    Button { editing = custom } label: { Label("Upravit cvik", systemImage: "pencil") }
                        .buttonStyle(SecondaryButtonStyle())
                } else if info.catalog == nil {
                    Text("K tomuhle cviku zatím nic nemáme. Vytvoř si ho jako vlastní cvik s fotkou a poznámkami.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                if info.catalog != nil {
                    Text("Fotky: free-exercise-db, volné dílo.")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Text("Obecné rady, ne rada trenéra ani lékaře. Když něco bolí, přestaň.")
                    .scaledFont(.caption)
                    .foregroundStyle(Theme.textTertiary)
                if let onAdd {
                    Button {
                        Haptics.success()
                        onAdd()
                    } label: {
                        Label("PŘIDAT DO TRÉNINKU", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(Theme.screenPadding)
            .padding(.top, 8)
        }
        .screenBackground()
        .appAppearance()
        .onAppear { shown = true }
        .sheet(item: $editing) { CustomExerciseEditor(exercise: $0) }
    }

    private func muscleIntensity(_ info: ExerciseInfo) -> [Muscle: Double] {
        let secondary = (info.catalog?.secondary ?? []).filter { !info.primary.contains($0) }
        return Dictionary(uniqueKeysWithValues: info.primary.map { ($0, 1.0) } + secondary.map { ($0, 0.45) })
    }
}

/// Making or changing an own exercise: name, photo from the camera or the library, muscles, equipment, notes.
struct CustomExerciseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CustomExercise
    @State private var photo: UIImage?
    @State private var removesPhoto = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var confirmsDelete = false
    private let isNew: Bool
    private let store = CustomExerciseStore.shared
    /// Called with the name after saving, so the new exercise can go straight into the workout.
    var onSave: ((String) -> Void)?

    init(exercise: CustomExercise? = nil, name: String = "", onSave: ((String) -> Void)? = nil) {
        _draft = State(initialValue: exercise ?? CustomExercise(name: name))
        isNew = exercise == nil
        self.onSave = onSave
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameTaken: Bool {
        guard !trimmedName.isEmpty else { return false }
        if ExerciseCatalog.named(trimmedName) != nil { return true }
        return store.exercises.contains { $0.id != draft.id && $0.name.activityKey == trimmedName.activityKey }
    }

    private var currentPhoto: UIImage? {
        if let photo { return photo }
        return removesPhoto ? nil : store.photo(of: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photoSection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NÁZEV").labelStyle()
                        TextField("Třeba Přítahy na kruzích", text: $draft.name)
                            .scaledFont(.body)
                            .card()
                        if nameTaken {
                            Text("Cvik s tímhle názvem už existuje.")
                                .scaledFont(.caption)
                                .foregroundStyle(Theme.orange)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CO HLAVNĚ POSILUJE").labelStyle()
                        FlowLayout(spacing: 8) {
                            ForEach(Muscle.allCases) { muscle in
                                chip(muscle.title, isOn: draft.primary.contains(muscle)) {
                                    if let index = draft.primary.firstIndex(of: muscle) {
                                        draft.primary.remove(at: index)
                                    } else {
                                        draft.primary.append(muscle)
                                    }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VYBAVENÍ").labelStyle()
                        FlowLayout(spacing: 8) {
                            ForEach(Equipment.allCases) { item in
                                chip(item.title, isOn: draft.equipment == item) { draft.equipment = item }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TECHNIKA").labelStyle()
                        TextField("Jak to dělat správně, na co si dát pozor", text: $draft.technique, axis: .vertical)
                            .lineLimit(3...8)
                            .scaledFont(.body)
                            .card()
                    }
                    if !isNew {
                        Button(role: .destructive) { confirmsDelete = true } label: {
                            Label("Smazat cvik", systemImage: "trash")
                        }
                        .buttonStyle(SecondaryButtonStyle(textColor: Theme.red))
                    }
                }
                .padding(Theme.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(isNew ? "Vlastní cvik" : "Upravit cvik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Vytvořit" : "Uložit", action: save)
                        .fontWeight(.bold)
                        .disabled(trimmedName.isEmpty || nameTaken || currentPhoto == nil)
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                CameraPicker { image in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { photo = image; removesPhoto = false }
                }
                .ignoresSafeArea()
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { photo = image; removesPhoto = false }
                    }
                    pickerItem = nil
                }
            }
            .alert("Smazat \(trimmedName)?", isPresented: $confirmsDelete) {
                Button("Smazat", role: .destructive) {
                    store.delete(draft)
                    dismiss()
                }
                Button("Nechat", role: .cancel) {}
            } message: {
                Text("Historie tohoto cviku ve statistikách zůstane.")
            }
        }
        .appAppearance()
    }

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.cardRaised)
                if let currentPhoto {
                    Image(uiImage: currentPhoto)
                        .resizable()
                        .scaledToFill()
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Přidej fotku cviku, třeba stroje nebo pozice. Bez ní cvik nepůjde uložit.")
                            .multilineTextAlignment(.center)
                            .scaledFont(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            HStack(spacing: 10) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        Haptics.light()
                        showsCamera = true
                    } label: { Label("Vyfotit", systemImage: "camera") }
                    .buttonStyle(PillButtonStyle(kind: .primary))
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Z galerie", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                if currentPhoto != nil {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { photo = nil; removesPhoto = true }
                    } label: { Label("Odebrat", systemImage: "trash") }
                    .buttonStyle(PillButtonStyle(kind: .destructive))
                }
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        } label: {
            Text(title)
                .scaledFont(.caption, weight: .semibold)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .background(isOn ? Theme.textPrimary : Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(PillPressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func save() {
        draft.name = trimmedName
        draft.technique = draft.technique.trimmingCharacters(in: .whitespacesAndNewlines)
        store.save(draft, photo: photo, removesPhoto: removesPhoto)
        Haptics.success()
        onSave?(draft.name)
        dismiss()
    }
}
