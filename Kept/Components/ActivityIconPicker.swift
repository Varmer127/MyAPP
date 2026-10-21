import SwiftUI

/// A sheet with a curated set of icons for an activity, grouped by theme.
struct ActivityIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    let activity: String
    let selected: String
    let onPick: (String) -> Void

    private struct IconGroup: Identifiable {
        let title: String
        let symbols: [String]
        var id: String { title }
    }

    private static let groups: [IconGroup] = [
        IconGroup(title: "Sport a pohyb", symbols: [
            "dumbbell", "figure.strengthtraining.traditional", "figure.run", "figure.walk", "figure.hiking",
            "figure.outdoor.cycle", "bicycle", "figure.pool.swim", "figure.yoga", "figure.core.training",
            "figure.boxing", "figure.martial.arts", "figure.climbing", "figure.skiing.downhill",
            "figure.soccer", "figure.basketball", "figure.tennis",
        ]),
        IconGroup(title: "Učení a mysl", symbols: [
            "book", "books.vertical", "text.book.closed", "character.book.closed", "graduationcap",
            "lightbulb", "brain.head.profile", "translate", "globe.europe.africa", "pencil.and.ruler",
        ]),
        IconGroup(title: "Práce", symbols: [
            "briefcase", "laptopcomputer", "chevron.left.forwardslash.chevron.right", "doc.text",
            "list.bullet.clipboard", "chart.bar", "envelope", "phone", "calendar", "banknote",
            "hammer", "wrench.and.screwdriver",
        ]),
        IconGroup(title: "Tvoření", symbols: [
            "paintbrush", "paintpalette", "music.note", "guitars", "pianokeys", "mic",
            "camera", "film", "theatermasks", "scissors", "gamecontroller",
        ]),
        IconGroup(title: "Zdraví a klid", symbols: [
            "heart", "figure.mind.and.body", "bed.double", "drop", "fork.knife", "carrot",
            "cup.and.saucer", "pills", "stethoscope", "sun.max", "moon.stars",
        ]),
        IconGroup(title: "Příroda a domov", symbols: [
            "leaf", "tree", "mountain.2", "pawprint", "dog", "house", "cart", "bag",
            "car", "airplane", "person.2", "gift",
        ]),
        IconGroup(title: "Ostatní", symbols: [
            "star", "flame", "target", "sparkles", "checkmark.seal", "circle.grid.2x2",
        ]),
    ]

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Self.groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.title.uppercased()).labelStyle()
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(group.symbols, id: \.self) { symbol in
                                    tile(symbol)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.screenPadding)
            }
            .screenBackground()
            .navigationTitle("Ikona: \(activity)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { dismiss() } }
            }
        }
        .appAppearance()
        .presentationDetents([.medium, .large])
    }

    private func tile(_ symbol: String) -> some View {
        let isOn = symbol == selected
        return Button {
            onPick(symbol)
            dismiss()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(isOn ? Theme.textPrimary : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A tappable icon tile that opens the icon picker.
struct ActivityIconButton: View {
    let activity: String
    let symbol: String
    let onPick: (String) -> Void
    @State private var isPicking = false

    var body: some View {
        Button { isPicking = true } label: {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .background(Theme.cardRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary, Theme.card)
                        .offset(x: 4, y: 4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Změnit ikonu aktivity \(activity)")
        .sheet(isPresented: $isPicking) {
            ActivityIconPicker(activity: activity, selected: symbol, onPick: onPick)
        }
    }
}
