import Foundation

/// Small rules for managing wallets in Settings.
enum WalletRules {
    /// A wallet with history, or a bill pointing at it, can only be archived:
    /// deleting it would orphan those transactions and quietly change every
    /// other balance's story.
    static func canDelete(_ id: UUID, entries: [Entry], ruleAccountIDs: Set<UUID>) -> Bool {
        !ruleAccountIDs.contains(id) && !entries.contains { $0.accountID == id || $0.toAccountID == id }
    }

    /// The editor takes a positive number. For a credit card that number is
    /// what you owe, stored as a negative opening balance (like Balance Check).
    static func storedOpening(entered: Int, kind: AccountKind) -> Int {
        kind == .credit ? -abs(entered) : abs(entered)
    }

    static func enteredOpening(stored: Int, kind: AccountKind) -> Int {
        kind == .credit ? max(0, -stored) : max(0, stored)
    }
}
