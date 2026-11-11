import Foundation
import Testing
@testable import Kept

struct LegalDocumentTests {
    /// Every document is in the app in both languages and opens with its title.
    @Test func everyDocumentLoadsInBothLanguages() {
        for document in LegalDocument.allCases {
            for language in LegalLanguage.allCases {
                let blocks = LegalBlock.blocks(from: document.markdown(in: language) ?? "")
                #expect(blocks.first?.kind == .title, "\(document.rawValue)-\(language.rawValue) is missing or has no title")
                #expect(blocks.count > 20)
            }
        }
    }

    /// The two language versions have the same sections and the same number of points, so one cannot drift from the other unnoticed.
    @Test func languageVersionsHaveTheSameShape() {
        for document in LegalDocument.allCases {
            let czech = LegalBlock.blocks(from: document.markdown(in: .cs) ?? "")
            let english = LegalBlock.blocks(from: document.markdown(in: .en) ?? "")
            #expect(czech.map(\.kind) == english.map(\.kind), "\(document.rawValue): Czech and English differ in structure")
        }
    }

    /// Each version says that the English one decides.
    @Test func everyVersionNamesTheBindingLanguage() {
        for document in LegalDocument.allCases {
            #expect(document.markdown(in: .cs)?.contains("má přednost anglická verze") == true)
            #expect(document.markdown(in: .en)?.contains("the English version prevails") == true)
        }
    }

    /// The version the server stores on acceptance is the one written in the Terms themselves.
    @Test func termsVersionMatchesTheDocuments() {
        let version = LegalDocument.termsVersion
        #expect(LegalDocument.terms.markdown(in: .en)?.contains("Version \(version) ") == true)
        #expect(LegalDocument.terms.markdown(in: .cs)?.contains("Verze \(version) ") == true)
    }

    @Test func readsHeadingsParagraphsAndBullets() {
        let blocks = LegalBlock.blocks(from: "# Title\n\nFirst line\nsecond line\n\n## Part\n- one\n- two\n")
        #expect(blocks.map(\.kind) == [.title, .paragraph, .heading, .bullet, .bullet])
        #expect(blocks[1].text == "First line second line")
        #expect(blocks[4].text == "two")
    }
}
