import Foundation
import SwiftData

/// A transaction category — an emoji icon plus a named color, scoped to
/// either income or expense. Mirrors the reference web app's `Category`
/// (src/db/types.ts) minus sync-only fields (no sync in the MVP). `order`
/// keeps the curated default sequence (src/db/seed.ts) stable in pickers;
/// a drag-to-reorder *UI* is still deferred, this just gives it a field to
/// write to later without a schema migration.
@Model
final class Category {
    var id: UUID
    var name: String
    /// Emoji, e.g. "🍔".
    var icon: String
    var color: CategoryColor
    var kind: TransactionType
    var order: Int

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        color: CategoryColor,
        kind: TransactionType,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.kind = kind
        self.order = order
    }
}
