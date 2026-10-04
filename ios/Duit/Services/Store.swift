import Foundation
import SwiftData

/// Opens the SwiftData store. If an existing store can't be opened or
/// migrated, it's moved aside (never deleted) and a fresh one is created, so
/// a bad migration can't crash-loop the app or silently destroy data. The
/// moved files stay on the phone as `default.store.backup-<time>`.
enum Store {
    static let modelTypes: [any PersistentModel.Type] = [
        Transaction.self, Category.self, Account.self, Budget.self, RecurringRule.self, SplitBucket.self,
    ]

    /// Set when the previous store had to be set aside; the UI tells the user once.
    static let resetFlagKey = "storeWasSetAside"

    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: Schema(modelTypes))
        } catch {
            setAsideExistingStore()
            UserDefaults.standard.set(true, forKey: resetFlagKey)
            do {
                return try ModelContainer(for: Schema(modelTypes))
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    /// An in-memory store for tests and previews.
    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: Schema(modelTypes), configurations: config)
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }

    private static func setAsideExistingStore() {
        let fm = FileManager.default
        let directory = ModelConfiguration().url.deletingLastPathComponent()
        let stamp = Int(Date().timeIntervalSince1970)
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix("default.store") && !file.lastPathComponent.contains(".backup-") {
            let target = file.deletingLastPathComponent().appendingPathComponent("\(file.lastPathComponent).backup-\(stamp)")
            try? fm.moveItem(at: file, to: target)
        }
    }
}
