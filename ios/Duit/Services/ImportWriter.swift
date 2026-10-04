import Foundation
import SwiftData

/// Writes an `ImportPlan` into the database, and takes the new rows back out
/// for Undo. Like `EntryWriter`, it is the only place that does this.
enum ImportWriter {
    struct Committed {
        /// The transactions that were added.
        var ids: [UUID]
        var walletsCreated: [String]
    }

    /// Creates the wallets the file named that don't exist yet (starting balance
    /// Rp 0, a type guessed from the name), then adds every new row. Saves once.
    @discardableResult
    static func commit(_ plan: ImportPlan, into context: ModelContext) -> Committed {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []

        var wallets: [String: Account] = [:]
        for account in accounts where wallets[CSVImport.normalise(account.name)] == nil {
            wallets[CSVImport.normalise(account.name)] = account
        }
        var nextOrder = (accounts.map(\.order).max() ?? -1) + 1
        var created: [String] = []
        for name in plan.newWallets where wallets[CSVImport.normalise(name)] == nil {
            let account = Account(name: name, kind: WalletGuess.kind(for: name), order: nextOrder)
            nextOrder += 1
            context.insert(account)
            wallets[CSVImport.normalise(name)] = account
            created.append(name)
        }

        var ids: [UUID] = []
        for item in plan.items {
            guard let account = wallets[CSVImport.normalise(item.accountName)] else { continue }
            let toAccount = item.toAccountName.flatMap { wallets[CSVImport.normalise($0)] }
            if item.row.type == .transfer && toAccount == nil { continue }
            let transaction = Transaction(
                type: item.row.type,
                amount: item.row.amount,
                category: category(for: item, in: categories),
                note: item.row.title,
                date: item.row.date,
                account: account,
                toAccount: toAccount,
                rating: item.row.rating
            )
            // A Duit export keeps each transaction's id, so importing it again
            // (or on top of the same data) finds them and adds nothing twice.
            if let id = item.row.id { transaction.id = id }
            context.insert(transaction)
            ids.append(transaction.id)
        }
        try? context.save()
        return Committed(ids: ids, walletsCreated: created)
    }

    /// The category named in the file (or guessed from history), else the
    /// kind's "Other". Transfers have none.
    private static func category(for item: ImportPlan.Item, in categories: [Category]) -> Category? {
        let kind = item.row.type
        guard kind != .transfer else { return nil }
        if let name = item.categoryName {
            let wanted = CSVImport.normalise(name)
            if let match = categories.first(where: { $0.kind == kind && CSVImport.normalise($0.name) == wanted }) {
                return match
            }
        }
        return categories.first { $0.kind == kind && $0.name == "Other" }
    }

    /// Undo: removes exactly the transactions an import added. Wallets it
    /// created stay (they're empty and harmless; archive or delete them in Settings).
    static func remove(ids: [UUID], from context: ModelContext) {
        let wanted = Set(ids)
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        for transaction in all where wanted.contains(transaction.id) {
            context.delete(transaction)
        }
        try? context.save()
    }
}
