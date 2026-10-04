import SwiftUI
import SwiftData

/// App entry point. Root is Transaction History for now (see its header
/// comment) — swap for the real Dashboard once this vertical slice
/// (Add Transaction → SwiftData → Transaction History → survives restart)
/// is confirmed stable; see docs/IOS_NATIVE_PLAN.md §8.
@main
struct DuitApp: App {
    let container: ModelContainer

    init() {
        // Fonts must be registered before the first view asks for them.
        DuitFonts.registerAll()
        container = Store.makeContainer()
        let context = container.mainContext
        DefaultCategories.seedIfNeeded(context)
        DefaultAccounts.seedIfNeeded(context)
        DefaultAccounts.backfillLegacyTransactions(context)
        DefaultSplitBuckets.seedIfNeeded(context)
    }

    var body: some Scene {
        WindowGroup {
            TransactionHistoryView()
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
