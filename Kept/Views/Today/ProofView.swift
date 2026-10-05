import SwiftUI
import PhotosUI

/// Proof of completion being entered: a photo, a short note, or both.
struct ProofDraft {
    var note = ""
    var photo: Data?

    static let minimumNoteLength = 3

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { photo != nil || trimmedNote.count >= Self.minimumNoteLength }

    func apply(to task: TaskItem) {
        task.proofNote = trimmedNote
        task.proofPhoto = photo
    }
}

/// Photo picker + note field, shared by every completion sheet that needs proof.
struct ProofInput: View {
    @Binding var draft: ProofDraft
    @State private var pickerItem: PhotosPickerItem?

    private static let maxDimension: CGFloat = 1600
    private static let jpegQuality = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DŮKAZ").labelStyle()
            if let photo = draft.photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                Button("Odebrat fotku") {
                    draft.photo = nil
                    pickerItem = nil
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Vybrat fotku", systemImage: "photo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.cardRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
            }
            TextField("Nebo krátká poznámka, např. „strany 120–165“", text: $draft.note, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(size: 16))
                .card()
            if !draft.isValid {
                Text("Přidej fotku nebo poznámku.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.orange)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                draft.photo = Self.compressed(data)
            }
        }
    }

    /// Photos are stored on the device for good, so they are scaled down first.
    private static func compressed(_ data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: jpegQuality) ?? data
    }
}

/// Asked before a task with "require proof" can be marked done.
struct ProofView: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    @State private var draft = ProofDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SPLNĚNÍ").labelStyle()
                        Text(task.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Tento úkol vyžaduje důkaz.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ProofInput(draft: $draft)
                }
                .padding(Theme.screenPadding)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button("ULOŽIT A SPLNIT") {
                    draft.apply(to: task)
                    task.markDone()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!draft.isValid)
                Button("ZRUŠIT") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Theme.screenPadding)
        }
        .screenBackground()
        .preferredColorScheme(.dark)
    }
}
