import SwiftUI

/// The documents a person can read before creating an account and at any time in Settings.
/// The texts live in `Kept/Resources/Legal` as plain Markdown, one file per language, so a lawyer can edit them
/// without touching code and the same files can go on the website.
enum LegalDocument: String, Identifiable, CaseIterable {
    case terms, privacy

    var id: String { rawValue }

    /// The version of the Terms bundled in this build. The server stores it with the time of acceptance,
    /// so it must match the version line at the top of both Terms files (a test checks it).
    static let termsVersion = "0.1"

    var title: LocalizedStringKey {
        switch self {
        case .terms: "Podmínky používání"
        case .privacy: "Zásady ochrany soukromí"
        }
    }

    var symbol: String {
        switch self {
        case .terms: "doc.text"
        case .privacy: "hand.raised"
        }
    }

    func markdown(in language: LegalLanguage) -> String? {
        guard let url = Bundle.main.url(forResource: "legal-\(rawValue)-\(language.rawValue)", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

/// Both documents exist in Czech and in English; the English version is the binding one.
enum LegalLanguage: String, CaseIterable, Identifiable {
    case cs, en

    var id: String { rawValue }

    /// The name of each language in that language, so it is not translated.
    var title: String {
        switch self {
        case .cs: "Česky"
        case .en: "English"
        }
    }

    /// The app speaks Czech for now, so the Czech translation opens first; the English one is binding.
    static let initial = LegalLanguage.cs
}

/// One piece of a document: its title, a section heading, a paragraph or a bullet.
struct LegalBlock: Identifiable, Equatable {
    enum Kind: Equatable { case title, heading, paragraph, bullet }

    let id: Int
    let kind: Kind
    let text: String

    /// Reads the small part of Markdown the documents use: "# ", "## ", "- " and paragraphs split by empty lines.
    static func blocks(from markdown: String) -> [LegalBlock] {
        var blocks: [LegalBlock] = []
        var paragraph: [String] = []

        func add(_ kind: Kind, _ text: String) {
            blocks.append(LegalBlock(id: blocks.count, kind: kind, text: text))
        }
        func flush() {
            guard !paragraph.isEmpty else { return }
            add(.paragraph, paragraph.joined(separator: " "))
            paragraph = []
        }

        for raw in markdown.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("## ") {
                flush()
                add(.heading, String(line.dropFirst(3)))
            } else if line.hasPrefix("# ") {
                flush()
                add(.title, String(line.dropFirst(2)))
            } else if line.hasPrefix("- ") {
                flush()
                add(.bullet, String(line.dropFirst(2)))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    /// The text with its bold parts. The documents are ours, so reading their Markdown is safe.
    var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

/// A document with a switch between Czech and English.
struct LegalDocumentView: View {
    let document: LegalDocument
    @State private var language = LegalLanguage.initial

    private var blocks: [LegalBlock] {
        LegalBlock.blocks(from: document.markdown(in: language) ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Jazyk dokumentu", selection: $language) {
                    ForEach(LegalLanguage.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 6)
                .onChange(of: language) { _, _ in Haptics.light() }

                if blocks.isEmpty {
                    Text("Dokument se nepodařilo načíst.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(blocks) { block in row(block) }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .animation(.easeInOut(duration: 0.2), value: language)
        }
        .screenBackground()
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    @ViewBuilder
    private func row(_ block: LegalBlock) -> some View {
        switch block.kind {
        case .title:
            Text(block.attributed)
                .scaledFont(.title, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case .heading:
            Text(block.attributed)
                .scaledFont(.heading, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)
        case .paragraph:
            Text(block.attributed)
                .scaledFont(.body)
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: "•")
                    .scaledFont(.body, weight: .bold)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
                Text(block.attributed)
                    .scaledFont(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The same document over another screen (the registration), with its own way out.
struct LegalDocumentSheet: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LegalDocumentView(document: document)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Zavřít") { dismiss() }
                    }
                }
        }
        .appAppearance()
    }
}

/// The two rows in Settings that open the documents.
struct LegalSection: View {
    var body: some View {
        Section("Dokumenty") {
            ForEach(LegalDocument.allCases) { document in
                NavigationLink {
                    LegalDocumentView(document: document)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: document.symbol)
                            .scaledFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(Theme.cardRaised)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)
                        Text(document.title)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .listRowBackground(Theme.card)
    }
}

/// The consent in the registration: one tick for the terms, with both documents one tap away.
struct LegalConsent: View {
    @Binding var isAccepted: Bool
    @State private var shown: LegalDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isAccepted.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                        .scaledFont(.title, weight: .semibold)
                        .foregroundStyle(isAccepted ? Theme.green : Theme.textSecondary)
                        .symbolEffect(.bounce, value: isAccepted)
                        .accessibilityHidden(true)
                    Text("Souhlasím s Podmínkami používání a beru na vědomí Zásady ochrany soukromí.")
                        .scaledFont(.body)
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PillPressStyle())
            .accessibilityAddTraits(isAccepted ? .isSelected : [])
            .accessibilityHint("Zaškrtnutím přijímáš podmínky.")

            // Side by side where they fit, under each other on a narrow screen or with large text.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { links }
                VStack(alignment: .leading, spacing: 8) { links }
            }
        }
        .sheet(item: $shown) { LegalDocumentSheet(document: $0) }
    }

    private var links: some View {
        ForEach(LegalDocument.allCases) { document in
            Button {
                Haptics.light()
                shown = document
            } label: {
                Label(document.title, systemImage: document.symbol)
                    .scaledFont(.caption, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Theme.cardRaised)
                    .clipShape(Capsule())
            }
            .buttonStyle(PillPressStyle())
        }
    }
}
