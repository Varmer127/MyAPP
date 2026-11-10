import Foundation
import Testing
@testable import Kept

struct ExerciseTechniqueTests {
    @Test func everyLibraryExerciseHasItsTechnique() {
        for exercise in ExerciseCatalog.all {
            let technique = ExerciseTechnique.of(exercise.name)
            #expect(technique != nil, "\(exercise.name) has no technique")
            #expect(technique?.steps.count ?? 0 >= 3, "\(exercise.name) needs at least three steps")
            #expect(technique?.mistakes.isEmpty == false, "\(exercise.name) needs its usual mistakes")
        }
    }

    /// The library shows only exercises with photos: every one needs its start photo, and its end photo too.
    @Test @MainActor func everyLibraryExerciseHasItsPhotos() {
        for exercise in ExerciseCatalog.all {
            #expect(ExercisePhoto.image(exercise.photo, frame: 0) != nil, "\(exercise.name) has no start photo")
            #expect(ExercisePhoto.image(exercise.photo, frame: 1) != nil, "\(exercise.name) has no end photo")
        }
    }

    @Test func libraryNamesAreUnique() {
        let keys = ExerciseCatalog.all.map(\.name.activityKey)
        #expect(Set(keys).count == keys.count)
    }

    @Test func techniqueIsFoundWhateverTheCase() {
        #expect(ExerciseTechnique.of("bench PRESS") != nil)
        #expect(ExerciseTechnique.of("Něco, co neexistuje") == nil)
    }
}

struct ExerciseSearchTests {
    private func found(_ query: String) -> [String] {
        ExerciseCatalog.all.filter { ExerciseSearch.matches(query, in: [$0.name, $0.english]) }.map(\.name)
    }

    @Test func findsByEnglishNamesAndNicknames() {
        #expect(found("lat pulldown").contains("Stahování kladky"))
        #expect(found("OHP").contains("Tlaky nad hlavu"))
        #expect(found("rdl").contains("Rumunský mrtvý tah"))
        #expect(found("skull crusher").contains("Francouzský tlak"))
        #expect(found("bulgarian").contains("Bulharský dřep"))
    }

    /// Words in any order, with or without hyphens and diacritics.
    @Test func ignoresOrderHyphensAndDiacritics() {
        #expect(found("pulldown lat").contains("Stahování kladky"))
        #expect(found("pushups").contains("Kliky"))
        #expect(found("push-ups").contains("Kliky"))
        #expect(found("bulharsky drep").contains("Bulharský dřep"))
    }

    @Test func everyCatalogExerciseHasAnEnglishName() {
        for exercise in ExerciseCatalog.all {
            #expect(!exercise.english.isEmpty, "\(exercise.name) has no English name")
        }
    }

    @Test func showsTheEnglishNameOnlyWhenTheCzechOneDoesNotFit() {
        let pulldown = ExerciseCatalog.named("Stahování kladky")
        #expect(pulldown?.englishMatch(for: "lat pulldown") == "Lat Pulldown")
        #expect(pulldown?.englishMatch(for: "stahování") == nil)
    }
}
