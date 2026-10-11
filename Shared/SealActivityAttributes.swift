import ActivityKit
import Foundation

/// Data of the Live Activity that counts down to a handed-in weekly plan being sealed.
struct SealActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var sealDate: Date
        var commitments: Int
    }

    var weekNumber: Int
}
