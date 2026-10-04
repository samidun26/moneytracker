import Foundation
import SwiftData

/// A monthly spending limit (src/db/types.ts `Budget`). A nil `categoryID`
/// is the overall budget — the user's "spending money" that powers the
/// Tanggal Tua battery. The category is stored as a plain id rather than a
/// relationship so deleting a category can never turn its budget into the
/// overall one.
@Model
final class Budget {
    var id: UUID
    var categoryID: UUID?
    /// Monthly limit, integer rupiah.
    var amount: Int

    init(id: UUID = UUID(), categoryID: UUID? = nil, amount: Int) {
        self.id = id
        self.categoryID = categoryID
        self.amount = amount
    }
}

/// One slot in the Payday Split ("Kos", "Savings", "Family"...): money given
/// a job before the rest becomes spending money. Names and amounts are
/// editable in Settings.
@Model
final class SplitBucket {
    var id: UUID
    var name: String
    var color: CategoryColor
    /// Key into `SplitBucket.icons`.
    var iconKey: String
    var amount: Int
    var order: Int

    init(id: UUID = UUID(), name: String, color: CategoryColor, iconKey: String, amount: Int = 0, order: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.iconKey = iconKey
        self.amount = amount
        self.order = order
    }

    var icon: PixelRects { SplitBucket.icons[iconKey] ?? PixelIconData.box }

    static let icons: [String: PixelRects] = [
        "building": PixelIconData.building,
        "bank": PixelIconData.bank,
        "family": PixelIconData.family,
        "bulb": PixelIconData.bulb,
        "gift": PixelIconData.gift,
        "cart": PixelIconData.cart,
        "box": PixelIconData.box,
    ]
}
