import Foundation

/// Income, expense, or a transfer between two of the user's own accounts
/// (src/db/types.ts `TxType`). Transfers move money, so they never count as
/// spending or income in totals, budgets, or insights.
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    case transfer
}

/// The "was it worth it?" verdict a user gives a purchase (the prototype's
/// "Worth it" / "Nyesel" buttons).
enum WorthRating: String, Codable {
    case worth
    case regret
}
