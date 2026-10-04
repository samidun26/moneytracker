import SwiftUI
import SwiftData

/// App entry point: opens straight into the retro desk (AppShell) — no login.
/// Each profile has its own database; the screens get the open profile's.
@main
struct DuitApp: App {
    @State private var stores: ProfileStores

    init() {
        // Fonts must be registered before the first view asks for them.
        DuitFonts.registerAll()
        _stores = State(initialValue: ProfileStores())
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environment(stores)
                .modelContainer(stores.activeContainer())
        }
    }
}
