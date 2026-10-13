import Foundation
import SwiftData

/// Something bought with points in the shop. Kept as history, so the balance can always be replayed from it.
@Model
final class PointsPurchase {
    var kindRaw: String = ShopItem.streakInsurance.rawValue
    var date: Date = Date()
    var cost: Int = 0
    /// The day a streak insurance was spent on. Nil while it is still waiting.
    var usedOn: Date?

    init(_ item: ShopItem, now: Date = .now) {
        self.kindRaw = item.rawValue
        self.date = now
        self.cost = item.cost
    }

    var kind: ShopItem { ShopItem(rawValue: kindRaw) ?? .streakInsurance }
}

enum ShopItem: String, CaseIterable, Identifiable {
    /// Bought ahead; the first day that would break the streak spends it instead.
    case streakInsurance
    /// One more penalty-free postponement this month.
    case extraPostpone

    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .streakInsurance: 300
        case .extraPostpone: 400
        }
    }

    var title: String {
        switch self {
        case .streakInsurance: "Pojistka série"
        case .extraPostpone: "Odklad navíc"
        }
    }

    var symbol: String {
        switch self {
        case .streakInsurance: "shield.lefthalf.filled"
        case .extraPostpone: "arrow.uturn.right"
        }
    }

    var summary: String {
        switch self {
        case .streakInsurance: "Koupíš ji dopředu. Až jeden den nevyjde, spotřebuje se sama a plamínek nezhasne. Den se dál počítá do spolehlivosti."
        case .extraPostpone: "Jeden odklad bez postihu navíc pro tento měsíc, nad tvůj měsíční limit."
        }
    }

    /// Most unused pieces that can be held at once. Nil = no limit.
    var maxStored: Int? {
        switch self {
        case .streakInsurance: 2
        case .extraPostpone: nil
        }
    }
}
