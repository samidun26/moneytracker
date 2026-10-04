import SwiftUI
import SwiftData

/// App entry point: opens straight into the retro desk (AppShell) — no login.
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
            AppShell()
        }
        .modelContainer(container)
    }
}
