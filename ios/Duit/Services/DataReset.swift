import Foundation
import SwiftData

/// "Reset all data": empties the store and puts the first-launch defaults
/// back. The user's look (theme, palette, dots) and the Face ID setting are
/// preferences, not data, so they stay.
enum DataReset {
    static func eraseEverything(in context: ModelContext) {
        try? context.delete(model: Transaction.self)
        try? context.delete(model: RecurringRule.self)
        try? context.delete(model: Budget.self)
        try? context.delete(model: SplitBucket.self)
        try? context.delete(model: Account.self)
        try? context.delete(model: Category.self)
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
}
