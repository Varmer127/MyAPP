import SwiftUI

/// "I did part of it": the user rates how much of the task was really done.
/// The share scales what the task earns in every score, so it is never a free pass.
struct PartialView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    /// Called with the chosen share (0...1) and the note when the user confirms.
    let onConfirm: (Double, String) -> Void

    @State private var percent = 50.0
    @State private var note = ""

    private static let range = 10.0...90.0
    private static let step = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SPLNĚNO ČÁSTEČNĚ").labelStyle(Theme.orange)
                        Text(task.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(Int(percent)) %")
                            .font(.system(size: 72, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.15), value: percent)
                        Text("NA KOLIK JSI TO SPLNIL").labelStyle()
                        Slider(value: $percent, in: Self.range, step: Self.step)
                            .tint(.white)
                            .padding(.top, 8)
                    }
                    Text("Úkol se započítá jen z \(Int(percent)) %: do produktivity, dodržených slibů i spolehlivosti. Zbylých \(100 - Int(percent)) % je nedodržený slib.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CO CHYBĚLO").labelStyle()
                        TextField("Nepovinné – co jsi nestihl nebo vynechal", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .font(.system(size: 16))
                            .card()
                    }
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button("ULOŽIT JAKO \(Int(percent)) %") {
                    onConfirm(percent / 100, note.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("ZRUŠIT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }
}
