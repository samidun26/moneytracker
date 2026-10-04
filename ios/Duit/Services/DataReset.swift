import Foundation
import SwiftData

/// "Reset all data": empties the store and puts the first-launch defaults
/// back. The user's look (theme, palette, dots) and the Face ID setting are
/// preferences, not data, so they stay.
enum DataReset {
    static func eraseEverything(in context: ModelContext) {
        // One by one rather than a batch delete, so every delete rule runs
        // (wallets and categories let go of the transactions that used them).
        deleteAll(Transaction.self, in: context)
        deleteAll(RecurringRule.self, in: context)
        deleteAll(Budget.self, in: context)
        deleteAll(SplitBucket.self, in: context)
        deleteAll(Account.self, in: context)
        deleteAll(Category.self, in: context)
        try? context.save()

        DefaultCategories.seedIfNeeded(context)
        DefaultAccounts.seedIfNeeded(context)
        DefaultSplitBuckets.seedIfNeeded(context)
        try? context.save()

        let defaults = UserDefaults.standard
        for key in [Prefs.salary, Prefs.lastSplitPeriod, Prefs.lastExpenseAccount, Prefs.lastIncomeAccount, Store.resetFlagKey] {
            defaults.removeObject(forKey: key)
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        for item in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
            context.delete(item)
        }
    }
}
