import Foundation
import Observation
import UIKit

/// An exercise the user made up: a name, what it works, how to do it and an optional photo.
struct CustomExercise: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var primary: [Muscle] = []
    var equipment: Equipment = .other
    var technique: String = ""
    var hasPhoto = false
}

/// The user's own exercises, kept as a small file next to the photos in the app's folder.
/// Not in the database, so adding them needs no change of the data model.
@MainActor @Observable
final class CustomExerciseStore {
    static let shared = CustomExerciseStore()

    private(set) var exercises: [CustomExercise] = []

    private static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("CustomExercises", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static var indexURL: URL { folder.appendingPathComponent("exercises.json") }
    private static let photoSide: CGFloat = 900
    private static let photoQuality: CGFloat = 0.8

    private init() {
        if let data = try? Data(contentsOf: Self.indexURL),
           let decoded = try? JSONDecoder().decode([CustomExercise].self, from: data) {
            exercises = decoded
        }
    }

    func named(_ name: String) -> CustomExercise? {
        exercises.first { $0.name.activityKey == name.activityKey }
    }

    /// Saves a new or changed exercise. A photo of nil keeps the one it had; `removesPhoto` drops it.
    func save(_ exercise: CustomExercise, photo: UIImage?, removesPhoto: Bool = false) {
        var exercise = exercise
        if let photo, let data = Self.scaled(photo).jpegData(compressionQuality: Self.photoQuality) {
            try? data.write(to: Self.photoURL(exercise.id), options: .atomic)
            exercise.hasPhoto = true
        } else if removesPhoto {
            try? FileManager.default.removeItem(at: Self.photoURL(exercise.id))
            exercise.hasPhoto = false
        }
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        } else {
            exercises.append(exercise)
        }
        persist()
    }

    func delete(_ exercise: CustomExercise) {
        try? FileManager.default.removeItem(at: Self.photoURL(exercise.id))
        exercises.removeAll { $0.id == exercise.id }
        persist()
    }

    func photo(of exercise: CustomExercise) -> UIImage? {
        guard exercise.hasPhoto else { return nil }
        return UIImage(contentsOfFile: Self.photoURL(exercise.id).path)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        try? data.write(to: Self.indexURL, options: .atomic)
    }

    private static func photoURL(_ id: UUID) -> URL { folder.appendingPathComponent("\(id.uuidString).jpg") }

    /// Large camera photos are scaled down so they stay small on disk.
    private static func scaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > photoSide else { return image }
        let factor = photoSide / longest
        let size = CGSize(width: image.size.width * factor, height: image.size.height * factor)
        return UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}

/// Everything known about an exercise by its name: the built-in library first, then the user's own.
struct ExerciseInfo {
    let name: String
    let catalog: CatalogExercise?
    let custom: CustomExercise?

    @MainActor
    init(_ name: String) {
        self.name = name
        catalog = ExerciseCatalog.named(name)
        custom = catalog == nil ? CustomExerciseStore.shared.named(name) : nil
    }

    var primary: [Muscle] { catalog?.primary ?? custom?.primary ?? [] }
    var equipment: Equipment? { catalog?.equipment ?? custom?.equipment }
    var muscleLine: String { primary.map(\.title).joined(separator: ", ") }
}
