import Foundation
import SwiftData
import Observation

/// Owns the profiles: which exist, which one is open, and one database
/// (`ModelContainer`) per profile. The screens only ever see the open profile's
/// container, so they can't show or change another profile's money, and every
/// feature (Today, Insights, Payday Split, CSV import, widgets…) works
/// unchanged, scoped to the open profile by construction.
///
/// A container is opened the first time its profile is used and then kept: two
/// containers on the same file must never exist at once.
@MainActor
@Observable
final class ProfileStores {
    private(set) var registry: ProfileRegistry

    @ObservationIgnored private var containers: [UUID: ModelContainer] = [:]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let inMemory: Bool

    /// - Parameters:
    ///   - defaults: where the profile list is saved (tests pass their own).
    ///   - inMemory: for tests; no files are created.
    init(defaults: UserDefaults = .standard, inMemory: Bool = false) {
        self.defaults = defaults
        self.inMemory = inMemory
        registry = ProfileRegistry.load(from: defaults)
        Prefs.profile = ProfilePrefs.defaults(for: registry.active)
    }

    var profiles: [Profile] { registry.profiles }
    var active: Profile { registry.active }

    // MARK: Containers

    func activeContainer() -> ModelContainer {
        container(for: registry.active)
    }

    func container(for profile: Profile) -> ModelContainer {
        if let existing = containers[profile.id] { return existing }
        let made = inMemory ? Store.makeInMemoryContainer() : Store.makeContainer(storeName: profile.storeName)
        Self.seed(made)
        containers[profile.id] = made
        return made
    }

    /// First-launch defaults for a database: categories, wallets, buckets.
    /// Idempotent, so it is safe every time a container is opened.
    static func seed(_ container: ModelContainer) {
        let context = container.mainContext
        DefaultCategories.seedIfNeeded(context)
        DefaultAccounts.seedIfNeeded(context)
        DefaultAccounts.backfillLegacyTransactions(context)
        DefaultSplitBuckets.seedIfNeeded(context)
        try? context.save()
    }

    // MARK: Changes

    /// Opens another profile. The screens are rebuilt by the caller's `.id`.
    @discardableResult
    func select(_ id: UUID) -> Bool {
        var next = registry
        guard next.select(id) else { return false }
        commit(next)
        Prefs.profile = ProfilePrefs.defaults(for: next.active)
        return true
    }

    func add(name: String, swatch: Int) -> Result<Profile, ProfileError> {
        var next = registry
        let result = next.add(name: name, swatch: swatch)
        if case .success = result { commit(next) }
        return result
    }

    func rename(_ id: UUID, to name: String) -> ProfileError? {
        var next = registry
        let error = next.rename(id, to: name)
        if error == nil { commit(next) }
        return error
    }

    func recolor(_ id: UUID, swatch: Int) {
        var next = registry
        next.recolor(id, swatch: swatch)
        commit(next)
    }

    /// Deletes a profile for good: its entry, its database files and its settings.
    func remove(_ id: UUID) -> ProfileError? {
        var next = registry
        switch next.remove(id) {
        case .failure(let error):
            return error
        case .success(let removed):
            commit(next)
            containers[removed.id] = nil // close it before its files go
            if !inMemory { Store.deleteFiles(storeName: removed.storeName) }
            ProfilePrefs.erase(removed)
            return nil
        }
    }

    private func commit(_ next: ProfileRegistry) {
        registry = next
        next.save(to: defaults)
    }
}
