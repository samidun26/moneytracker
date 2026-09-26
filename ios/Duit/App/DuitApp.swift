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
        do {
            container = try ModelContainer(for: Transaction.self, Category.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        DefaultCategories.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            TransactionHistoryView()
        }
        .modelContainer(container)
    }
}
