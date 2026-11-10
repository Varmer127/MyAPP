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
