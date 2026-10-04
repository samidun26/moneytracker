import Foundation
import SwiftData

/// Opens the SwiftData store. If an existing store can't be opened or
/// migrated, it's moved aside (never deleted) and a fresh one is created, so
/// a bad migration can't crash-loop the app or silently destroy data. The
/// moved files stay on the phone as `default.store.backup-<time>`. Every
/// profile has its own database file; see `ProfileStores`.
enum Store {
    static let modelTypes: [any PersistentModel.Type] = [
        Transaction.self, Category.self, Account.self, Budget.self, RecurringRule.self, SplitBucket.self,
    ]

    /// Set when the previous store had to be set aside; the UI tells the user once.
    static let resetFlagKey = "storeWasSetAside"

    /// `storeName` nil is the app's original database (`default.store`), opened
    /// exactly as before profiles existed; any other name is another profile's
    /// own database file (`<name>.store`).
    static func makeContainer(storeName: String? = nil) -> ModelContainer {
        do {
            return try open(storeName)
        } catch {
            setAsideExistingStore(storeName: storeName)
            UserDefaults.standard.set(true, forKey: resetFlagKey)
            do {
                return try open(storeName)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    private static func open(_ storeName: String?) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        guard let storeName else { return try ModelContainer(for: schema) }
        return try ModelContainer(for: schema, configurations: ModelConfiguration(storeName, schema: schema))
    }

    /// Deletes a profile's database files (and any set-aside copies of it).
    /// The original database is never deleted this way.
    static func deleteFiles(storeName: String?) {
        guard let storeName else { return }
        let fm = FileManager.default
        for file in files(storeName: storeName, includingBackups: true) {
            try? fm.removeItem(at: file)
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

    private static func files(storeName: String?, includingBackups: Bool) -> [URL] {
        let configuration = storeName.map { ModelConfiguration($0) } ?? ModelConfiguration()
        let directory = configuration.url.deletingLastPathComponent()
        let prefix = "\(storeName ?? "default").store"
        let all = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return all.filter {
            $0.lastPathComponent.hasPrefix(prefix) && (includingBackups || !$0.lastPathComponent.contains(".backup-"))
        }
    }

    private static func setAsideExistingStore(storeName: String?) {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        for file in files(storeName: storeName, includingBackups: false) {
            let target = file.deletingLastPathComponent().appendingPathComponent("\(file.lastPathComponent).backup-\(stamp)")
            try? fm.moveItem(at: file, to: target)
        }
    }
}
