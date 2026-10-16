import Foundation
import SwiftData

/// One check-in of body measurements and, optionally, progress photos.
/// The photos are not stored here: only their file names in the private photo vault.
@Model
final class BodyEntry {
    var date: Date = Date()
    var weight: Double?
    var waist: Double?
    var chest: Double?
    var arm: Double?
    var thigh: Double?
    var hips: Double?
    /// File names in `PhotoVault`, keyed by pose ("front", "side", "back").
    var photosData: Data = Data()

    init(date: Date = .now) {
        self.date = date
    }

    var photos: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: photosData)) ?? [:] }
        set { photosData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
