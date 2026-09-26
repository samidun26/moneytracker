import Foundation
import SwiftData

/// A single income or expense entry. Amount is a positive integer rupiah —
/// `type` carries the sign, matching the reference web app's approach
/// (src/db/types.ts `Transaction`, src/lib/money.ts) to avoid float
/// rounding bugs. Clamping to `CurrencyFormatter.maxAmount` and rejecting
/// non-positive amounts is the input layer's job (the Add Transaction
/// view/view model), not this model's.
@Model
final class Transaction {
    var id: UUID
    var type: TransactionType
    var amount: Int
    @Relationship(deleteRule: .nullify)
    var category: Category?
    var note: String
    /// The calendar day this transaction belongs to (local day, not a
    /// timestamp) — see src/lib/dates.ts: a purchase at 23:30 belongs to
    /// that day regardless of timezone. Always store via
    /// `DateHelpers.startOfDay(_:)`.
    var date: Date
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Int,
        category: Category? = nil,
        note: String = "",
        date: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
