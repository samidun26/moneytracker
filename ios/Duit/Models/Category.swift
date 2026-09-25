import Foundation
import SwiftData

/// A transaction category — an emoji icon plus a named color, scoped to
/// either income or expense. Mirrors the reference web app's `Category`
/// (src/db/types.ts) minus sync-only fields (no sync in the MVP) and minus
/// manual reordering (not in MVP scope; a plain `order: Int` can be added
/// later without a painful migration if that's picked up).
@Model
final class Category {
    var id: UUID
    var name: String
    /// Emoji, e.g. "🍔".
    var icon: String
    var color: CategoryColor
    var kind: TransactionType

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: CategoryColor,
        kind: TransactionType
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.kind = kind
    }
}
