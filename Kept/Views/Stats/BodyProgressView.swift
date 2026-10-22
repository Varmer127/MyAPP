import SwiftUI
import SwiftData
import Charts

/// Body measurements and progress photos. Always behind Face ID, blurred whenever the app is not in front,
/// photos only from the camera and kept in the private photo vault.
struct BodyProgressView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \BodyEntry.date, order: .reverse) private var entries: [BodyEntry]
    @State private var editing: BodyEntry?
    @State private var comparing = false
    @State private var deleting: BodyEntry?

    private static let poses: [(key: String, title: String)] = [("front", "Zepředu"), ("side", "Z boku"), ("back", "Zezadu")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Míry a fotky").scaledFont(.title, weight: .bold).foregroundStyle(Theme.textPrimary)
                    Label("Jen v tomto telefonu, zašifrované, mimo zálohy a galerii.", systemImage: "lock.fill")
                        .scaledFont(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("NOVÝ ZÁPIS") {
                    let entry = BodyEntry()
                    context.insert(entry)
                    editing = entry
                }
                .buttonStyle(PrimaryButtonStyle())
                if entries.count >= 2 {
                    Button(comparing ? "SKRÝT POROVNÁNÍ" : "POROVNAT PRVNÍ A POSLEDNÍ") { withAnimation { comparing.toggle() } }
                        .buttonStyle(SecondaryButtonStyle())
                    if comparing, let first = entries.last, let last = entries.first {
                        comparison(first, last)
                    }
                }
                measurementsChart
                ForEach(entries) { entry in
                    Button { editing = entry } label: { entryCard(entry) }
                        .buttonStyle(.plain)
                        .swipeToDelete("Smazat zápis", cornerRadius: Theme.radius) { deleting = entry }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .sheet(item: $editing) { BodyEntryEditor(entry: $0) }
        .alert("Smazat zápis i jeho fotky?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Smazat", role: .destructive) {
                if let entry = deleting {
                    for name in entry.photos.values { PhotoVault.delete(name) }
                    context.delete(entry)
                }
                deleting = nil
            }
            Button("Zrušit", role: .cancel) { deleting = nil }
        }
        // Body photos never show in the app switcher.
        .overlay {
            if scenePhase != .active {
                Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
            }
        }
        .modifier(FaceIDLock(isEnabled: true, title: "Míry a fotky jsou zamčené", reason: "Odemknout míry a fotky"))
    }

    private func entryCard(_ entry: BodyEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.date.longDayText.uppercased()).labelStyle()
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
            }
            let values = Self.values(of: entry)
            if !values.isEmpty {
                Text(values.map { "\($0.0) \($0.1.formatted(.number.precision(.fractionLength(0...1)).locale(.app))) \($0.2)" }.joined(separator: " · "))
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
            }
            let photos = entry.photos
            if !photos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Self.poses, id: \.key) { pose in
                        if let name = photos[pose.key] {
                            VaultImage(name: name)
                                .frame(width: 72, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .card()
    }

    private func comparison(_ first: BodyEntry, _ last: BodyEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Self.poses, id: \.key) { pose in
                if let before = first.photos[pose.key], let after = last.photos[pose.key] {
                    Text(pose.title.uppercased()).labelStyle()
                    HStack(spacing: 8) {
                        VStack(spacing: 4) {
                            VaultImage(name: before).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(first.date.dayMonthText).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        VStack(spacing: 4) {
                            VaultImage(name: after).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(last.date.dayMonthText).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            let firstValues = Dictionary(uniqueKeysWithValues: Self.values(of: first).map { ($0.0, $0.1) })
            ForEach(Self.values(of: last), id: \.0) { label, value, unit in
                if let before = firstValues[label] {
                    let change = value - before
                    Text("\(label): \(change >= 0 ? "+" : "−")\(abs(change).formatted(.number.precision(.fractionLength(0...1)).locale(.app))) \(unit)")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var measurementsChart: some View {
        let points = entries.reversed().compactMap { entry in entry.waist.map { (entry.date, $0) } }
        if points.count >= 2 {
            VStack(spacing: 10) {
                SectionLabel(text: "Pas (cm)")
                Chart(points, id: \.0) { date, value in
                    LineMark(x: .value("Den", date), y: .value("cm", value))
                        .foregroundStyle(Theme.textPrimary)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Den", date), y: .value("cm", value))
                        .foregroundStyle(Theme.textPrimary)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
                .card()
            }
        }
    }

    static func values(of entry: BodyEntry) -> [(String, Double, String)] {
        [("Váha", entry.weight, "kg"), ("Pas", entry.waist, "cm"), ("Hrudník", entry.chest, "cm"),
         ("Paže", entry.arm, "cm"), ("Stehno", entry.thigh, "cm"), ("Boky", entry.hips, "cm")]
            .compactMap { label, value, unit in value.map { (label, $0, unit) } }
    }
}

/// A photo from the vault, loaded on demand and never cached elsewhere.
struct VaultImage: View {
    let name: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.cardRaised
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(Theme.textTertiary)
            }
        }
        .clipped()
        .task(id: name) { image = PhotoVault.load(name) }
        .accessibilityLabel("Fotka postavy")
    }
}

private struct BodyEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var entry: BodyEntry
    @State private var capturing: String?
    @State private var confirmsDelete = false
    @State private var noCamera = false

    private static let poses: [(key: String, title: String)] = [("front", "Zepředu"), ("side", "Z boku"), ("back", "Zezadu")]

    var body: some View {
        NavigationStack {
            Form {
                Section("Míry") {
                    field("Váha (kg)", $entry.weight)
                    field("Pas (cm)", $entry.waist)
                    field("Hrudník (cm)", $entry.chest)
                    field("Paže (cm)", $entry.arm)
                    field("Stehno (cm)", $entry.thigh)
                    field("Boky (cm)", $entry.hips)
                }
                .listRowBackground(Theme.card)
                Section {
                    HStack(spacing: 10) {
                        ForEach(Self.poses, id: \.key) { pose in
                            Button {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) { capturing = pose.key } else { noCamera = true }
                            } label: {
                                VStack(spacing: 6) {
                                    if let name = entry.photos[pose.key] {
                                        VaultImage(name: name).frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8).fill(Theme.cardRaised).frame(height: 120)
                                            .overlay(Image(systemName: "camera").foregroundStyle(Theme.textSecondary))
                                    }
                                    Text(pose.title).scaledFont(.caption).foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Fotky")
                } footer: {
                    Text("Jen fotoaparátem, nic se neukládá do galerie. Fotky jsou šifrované v telefonu, nejdou do iCloudu ani do zálohy a při smazání aplikace zmizí.")
                }
                .listRowBackground(Theme.card)
                Section {
                    Button("Smazat zápis", role: .destructive) { confirmsDelete = true }
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(entry.date.dayMonthText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Hotovo") { dismiss() } }
            }
            .fullScreenCover(item: Binding(get: { capturing.map(Pose.init) }, set: { capturing = $0?.key })) { pose in
                CameraPicker { image in
                    if let old = entry.photos[pose.key] { PhotoVault.delete(old) }
                    if let name = PhotoVault.save(image) { entry.photos[pose.key] = name }
                }
                .ignoresSafeArea()
            }
            .alert("Fotoaparát není dostupný", isPresented: $noCamera) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Fotky postavy jdou pořídit jen fotoaparátem, z galerie ne.")
            }
            .alert("Smazat zápis i jeho fotky?", isPresented: $confirmsDelete) {
                Button("Smazat", role: .destructive) {
                    for name in entry.photos.values { PhotoVault.delete(name) }
                    context.delete(entry)
                    dismiss()
                }
                Button("Zrušit", role: .cancel) {}
            }
        }
        .appAppearance()
    }

    private struct Pose: Identifiable {
        let key: String
        var id: String { key }
    }

    private func field(_ label: String, _ value: Binding<Double?>) -> some View {
        LabeledContent(label) {
            TextField("—", value: value, format: .number.precision(.fractionLength(0...1)).locale(.app))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
