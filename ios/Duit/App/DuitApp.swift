import SwiftUI
import SwiftData

/// App entry point. Placeholder root view — replace with the real Dashboard
/// once the first vertical slice (Add Transaction → SwiftData →
/// Transaction History → survives restart) is done; see
/// docs/IOS_NATIVE_PLAN.md §8.
@main
struct DuitApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Duit")
        }
        .modelContainer(for: [Transaction.self, Category.self])
    }
}
