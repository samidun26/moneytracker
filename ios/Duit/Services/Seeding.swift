import Foundation
import SwiftData

/// First-launch defaults for the things added after the first release.
/// Everything here is idempotent: safe to run on every launch.
enum DefaultAccounts {
    /// Cash, a bank and an e-wallet — the three the Terminal's slang knows.
    /// Rename or add more in Settings → Wallets.
    static let items: [(name: String, kind: AccountKind)] = [
        ("Cash", .cash), ("Bank", .bank), ("E-wallet", .ewallet),
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        guard existing == 0 else { return }
        for (index, item) in items.enumerated() {
            context.insert(Account(name: item.name, kind: item.kind, order: index))
        }
    }

    /// Transactions saved before wallets existed belonged to one implicit
    /// balance; they go to Cash (or the first wallet) so balances add up.
    static func backfillLegacyTransactions(_ context: ModelContext) {
        let accounts = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))) ?? []
        guard let home = accounts.first(where: { $0.kind == .cash }) ?? accounts.first else { return }
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for t in all where t.account == nil {
            t.account = home
        }
    }
}

enum DefaultSplitBuckets {
    static let items: [(name: String, color: CategoryColor, iconKey: String)] = [
        ("Rent", .indigo, "building"),
        ("Savings", .green, "bank"),
        ("Family", .orange, "family"),
        ("Bills & subscriptions", .yellow, "bulb"),
    ]

    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<SplitBucket>())) ?? 0
        guard existing == 0 else { return }
        for (index, item) in items.enumerated() {
            context.insert(SplitBucket(name: item.name, color: item.color, iconKey: item.iconKey, amount: 0, order: index))
        }
    }
}
