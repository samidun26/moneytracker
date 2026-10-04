import Foundation
import SwiftData

/// A single income, expense or transfer. Amount is a positive integer rupiah —
/// `type` carries the sign, matching the reference web app's approach
/// (src/db/types.ts `Transaction`, src/lib/money.ts) to avoid float
/// rounding bugs. Clamping to `CurrencyFormatter.maxAmount` and rejecting
/// non-positive amounts is the input layer's job (the Add Transaction
/// view/view model), not this model's.
///
/// Everything after `updatedAt` was added after the first release; each is
/// optional so SwiftData can migrate an existing store automatically.
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

    /// The account money leaves (expense, transfer) or enters (income).
    @Relationship(deleteRule: .nullify)
    var account: Account?
    /// Transfers only: the account money arrives in.
    @Relationship(deleteRule: .nullify)
    var toAccount: Account?
    /// Set when the user answers "worth it?" on a purchase.
    var rating: WorthRating?
    /// Set when this transaction was generated from a RecurringRule.
    var recurringID: UUID?
    /// Deterministic "<ruleID>|yyyy-MM-dd" so a recurring occurrence is
    /// never posted twice (src/domain/recurring.ts `recurringTxId`).
    var occurrenceKey: String?

    init(
        id: UUID = UUID(),
        type: TransactionType,
        amount: Int,
        category: Category? = nil,
        note: String = "",
        date: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        account: Account? = nil,
        toAccount: Account? = nil,
        rating: WorthRating? = nil,
        recurringID: UUID? = nil,
        occurrenceKey: String? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.account = account
        self.toAccount = toAccount
        self.rating = rating
        self.recurringID = recurringID
        self.occurrenceKey = occurrenceKey
    }
}
