import SwiftUI
import UniformTypeIdentifiers

/// A sealed week as a picture that can be sent to someone as a witness.
/// The picture is only rendered when the share sheet really asks for it.
struct SealedWeekShare: Transferable {
    struct Line: Hashable {
        let symbol: String
        let title: String
        let count: Int
    }

    let weekNumber: Int
    let range: String
    let sealed: String
    let lines: [Line]
    let total: Int

    init?(plan: WeeklyPlan) {
        guard let committedAt = plan.committedAt else { return nil }
        let snapshot = plan.originalSnapshot
        guard !snapshot.isEmpty else { return nil }
        weekNumber = plan.weekStart.weekNumber
        range = "\(plan.weekStart.dayMonthText) – \(plan.lastDay.dayMonthText)"
        sealed = committedAt.stampText
        lines = TaskCategory.allCases.compactMap { category in
            let count = snapshot.filter { $0.category == category }.count
            return count > 0 ? Line(symbol: category.icon, title: category.title, count: count) : nil
        }
        total = snapshot.count
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { share in
            try await share.png()
        }
        .suggestedFileName { "Kept – týden \($0.weekNumber).png" }
    }

    @MainActor
    private func png() throws -> Data {
        let renderer = ImageRenderer(content: SealedWeekCard(share: self))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
        return data
    }
}

/// The shared picture. It leaves the app, so it has one fixed dark look instead of following the appearance.
private struct SealedWeekCard: View {
    let share: SealedWeekShare

    private static let background = Color(hex: 0x0A0A0A)
    private static let primary = Color(hex: 0xFFFFFF)
    private static let secondary = Color(hex: 0x8E8E93)
    private static let orange = Color(hex: 0xFF9F0A)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("KEPT")
                    .scaledFont(.body, weight: .heavy)
                    .tracking(3)
                    .foregroundStyle(Self.primary)
                Spacer()
                Label("ZAPEČETĚNO", systemImage: "checkmark.seal.fill")
                    .scaledFont(.caption, weight: .bold)
                    .tracking(1)
                    .foregroundStyle(Self.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("TÝDEN \(share.weekNumber) · \(share.range)")
                    .scaledFont(.caption, weight: .semibold)
                    .tracking(1.2)
                    .foregroundStyle(Self.secondary)
                Text("TENTO TÝDEN SE ZAVAZUJI K:")
                    .scaledFont(.title, weight: .bold)
                    .foregroundStyle(Self.primary)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(share.lines, id: \.self) { line in
                    HStack(spacing: 10) {
                        Text("\(line.count)×")
                            .scaledFont(.heading, weight: .bold)
                            .frame(width: 44, alignment: .leading)
                        Image(systemName: line.symbol)
                            .scaledFont(.body)
                            .frame(width: 24)
                        Text(line.title)
                            .scaledFont(.heading)
                    }
                    .foregroundStyle(Self.primary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(share.total)")
                    .scaledFont(64, weight: .heavy)
                    .foregroundStyle(Self.primary)
                Text("ZÁVAZKŮ CELKEM")
                    .scaledFont(.caption, weight: .semibold)
                    .tracking(1.2)
                    .foregroundStyle(Self.secondary)
            }
            Text("Zapečetěno \(share.sealed). Změnit to už nejde bez postihu. Hlídej mě.")
                .scaledFont(.caption)
                .foregroundStyle(Self.secondary)
        }
        .padding(28)
        .frame(width: 360, height: 520, alignment: .topLeading)
        .background(Self.background)
    }
}
