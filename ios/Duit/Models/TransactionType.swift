import Foundation

/// Income vs. expense. `transfer` and multi-account movement are out of
/// scope for the MVP — see docs/IOS_NATIVE_PLAN.md §3 (Accounts is a later
/// slice, added once the core transaction flow is stable).
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
}
