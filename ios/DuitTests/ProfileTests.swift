import XCTest
import SwiftData
@testable import Duit

/// The rules for profiles (pure), and the promise behind them: what you do in
/// one profile cannot show up in, or change, another.
final class ProfileRegistryTests: XCTestCase {
    private func addUs(_ registry: inout ProfileRegistry) -> Profile {
        guard case .success(let profile) = registry.add(name: "Us", swatch: 1) else {
            XCTFail("could not add Us")
            return registry.active
        }
        return profile
    }

    func testAFreshInstallHasOneProfileThatIsTheExistingData() {
        let registry = ProfileRegistry.firstRun()
        XCTAssertEqual(registry.profiles.count, 1)
        XCTAssertEqual(registry.active.name, "Mine")
        XCTAssertTrue(registry.active.isOriginal, "it must open the original database, not a new one")
        XCTAssertEqual(registry.active.id, ProfileRegistry.originalID)
        XCTAssertEqual(ProfileRegistry.firstRun(), registry, "the same on every launch")
    }

    func testAddingNamesTrimsAndCapsAndGivesTheProfileItsOwnDatabase() {
        var registry = ProfileRegistry.firstRun()
        guard case .success(let profile) = registry.add(name: "  Trip   fund 2026 for the whole family  ", swatch: 3) else {
            return XCTFail("add failed")
        }
        XCTAssertEqual(profile.name, "Trip fund 2026")  // 14 characters, spaces collapsed
        XCTAssertEqual(profile.storeName, "profile-\(profile.id.uuidString)")
        XCTAssertFalse(profile.isOriginal)
        XCTAssertEqual(registry.profiles.count, 2)
        XCTAssertEqual(registry.active.name, "Mine", "adding does not switch")
    }

    func testBadNamesAndTooManyProfilesAreRefused() {
        var registry = ProfileRegistry.firstRun()
        XCTAssertEqual(registry.add(name: "   ", swatch: 0).failureValue, .emptyName)
        XCTAssertEqual(registry.add(name: "mine", swatch: 0).failureValue, .nameTaken, "names compare without case")
        for n in 1..<ProfileRegistry.maxProfiles {
            XCTAssertNotNil(try? registry.add(name: "P\(n)", swatch: 0).get())
        }
        XCTAssertEqual(registry.profiles.count, ProfileRegistry.maxProfiles)
        XCTAssertEqual(registry.add(name: "One more", swatch: 0).failureValue, .tooMany)
        XCTAssertFalse(ProfileError.tooMany.message.isEmpty)
    }

    func testSelectingOnlyWorksForARealProfile() {
        var registry = ProfileRegistry.firstRun()
        let us = addUs(&registry)
        XCTAssertTrue(registry.select(us.id))
        XCTAssertEqual(registry.active, us)
        XCTAssertFalse(registry.select(UUID()))
        XCTAssertEqual(registry.active, us)
    }

    func testRenamingKeepsNamesUnique() {
        var registry = ProfileRegistry.firstRun()
        let us = addUs(&registry)
        XCTAssertNil(registry.rename(us.id, to: "Together"))
        XCTAssertEqual(registry.profile(us.id)?.name, "Together")
        XCTAssertEqual(registry.rename(us.id, to: "MINE"), .nameTaken)
        XCTAssertEqual(registry.rename(us.id, to: " "), .emptyName)
        XCTAssertEqual(registry.rename(UUID(), to: "X"), .notFound)
        XCTAssertNil(registry.rename(us.id, to: "TOGETHER"), "changing only its own case is fine")
        registry.recolor(us.id, swatch: 5)
        XCTAssertEqual(registry.profile(us.id)?.swatch, 5)
    }

    func testTheOpenAndTheOriginalProfileCannotBeDeleted() {
        var registry = ProfileRegistry.firstRun()
        let us = addUs(&registry)
        XCTAssertEqual(registry.remove(ProfileRegistry.originalID).failureValue, .cannotRemoveActive)
        registry.select(us.id)
        XCTAssertEqual(registry.remove(us.id).failureValue, .cannotRemoveActive)
        XCTAssertEqual(registry.remove(ProfileRegistry.originalID).failureValue, .cannotRemoveOriginal)
        XCTAssertEqual(registry.remove(UUID()).failureValue, .notFound)

        registry.select(ProfileRegistry.originalID)
        XCTAssertEqual(try? registry.remove(us.id).get(), us)
        XCTAssertEqual(registry.profiles.count, 1)
    }

    func testTheListAndTheOpenProfileSurviveARestart() throws {
        let suite = "duit.test.registry.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var registry = ProfileRegistry.load(from: defaults)
        XCTAssertEqual(registry, ProfileRegistry.firstRun())
        let us = addUs(&registry)
        registry.select(us.id)
        registry.save(to: defaults)

        let back = ProfileRegistry.load(from: defaults)
        XCTAssertEqual(back, registry)
        XCTAssertEqual(back.active, us)
    }

    func testDamagedSavedDataFallsBackToTheOriginalProfile() throws {
        let suite = "duit.test.registry.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(Data("not json".utf8), forKey: ProfileRegistry.listKey)
        XCTAssertEqual(ProfileRegistry.load(from: defaults), ProfileRegistry.firstRun())

        // A saved "open profile" that no longer exists opens the original.
        var registry = ProfileRegistry.firstRun()
        _ = addUs(&registry)
        registry.save(to: defaults)
        defaults.set(UUID().uuidString, forKey: ProfileRegistry.activeKey)
        XCTAssertEqual(ProfileRegistry.load(from: defaults).active.id, ProfileRegistry.originalID)
    }

    func testSwatchesNeverIndexOutOfRange() {
        XCTAssertEqual(ProfileSwatch.color(-4), ProfileSwatch.all[0])
        XCTAssertEqual(ProfileSwatch.color(99), ProfileSwatch.all[ProfileSwatch.all.count - 1])
    }

    func testAProfilesExportFileNameSaysWhoseItIs() {
        let day = TestData.day(2026, 10, 4)
        XCTAssertEqual(CSVFile(entries: [], day: day, profile: nil).fileName, "duit-transactions-2026-10-04.csv")
        let original = ProfileRegistry.firstRun().active
        XCTAssertEqual(CSVFile(entries: [], day: day, profile: original).fileName, "duit-transactions-2026-10-04.csv")
        let us = Profile(id: UUID(), name: "Trip fund!", swatch: 0, storeName: "profile-x")
        XCTAssertEqual(CSVFile(entries: [], day: day, profile: us).fileName, "duit-trip-fund-transactions-2026-10-04.csv")
    }
}

@MainActor
final class ProfileStoresTests: XCTestCase {
    private var suites: [String] = []

    private func makeDefaults() throws -> UserDefaults {
        let suite = "duit.test.stores.\(UUID().uuidString)"
        suites.append(suite)
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() async throws {
        Prefs.profile = .standard
        for suite in suites { UserDefaults.standard.removePersistentDomain(forName: suite) }
        suites = []
    }

    private func entries(_ container: ModelContainer) throws -> [Entry] {
        try container.mainContext.fetch(FetchDescriptor<Transaction>()).map { Entry($0) }
    }

    func testTheFirstProfileUsesTheStandardSettingsSoNothingMoves() throws {
        let stores = ProfileStores(defaults: try makeDefaults(), inMemory: true)
        XCTAssertTrue(stores.active.isOriginal)
        XCTAssertTrue(Prefs.profile === UserDefaults.standard)
    }

    func testEachNewProfileStartsWithItsOwnSeededDatabase() throws {
        let stores = ProfileStores(defaults: try makeDefaults(), inMemory: true)
        let us = try XCTUnwrap(try stores.add(name: "Us", swatch: 1).get())
        let container = stores.container(for: us)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Account>()), 3, "Cash, Bank, E-wallet")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Duit.Category>()), DefaultCategories.items.count)
        XCTAssertEqual(try entries(container).count, 0)
    }

    func testWhatYouDoInOneProfileNeverReachesAnother() throws {
        let stores = ProfileStores(defaults: try makeDefaults(), inMemory: true)
        let mine = stores.container(for: stores.active)
        let us = try XCTUnwrap(try stores.add(name: "Us", swatch: 1).get())
        let ours = stores.container(for: us)

        mine.mainContext.insert(Transaction(type: .expense, amount: 32_000, note: "my coffee", date: TestData.day(2026, 10, 1)))
        let wallet = Account(name: "Joint account", kind: .bank, openingBalance: 5_000_000, order: 9)
        ours.mainContext.insert(wallet)
        ours.mainContext.insert(Transaction(type: .expense, amount: 450_000, note: "rent share", date: TestData.day(2026, 10, 1), account: wallet))
        try mine.mainContext.save()
        try ours.mainContext.save()

        XCTAssertEqual(try entries(mine).map(\.title), ["my coffee"])
        XCTAssertEqual(try entries(ours).map(\.title), ["rent share"])
        XCTAssertEqual(try mine.mainContext.fetch(FetchDescriptor<Account>()).filter { $0.name == "Joint account" }.count, 0)
        XCTAssertEqual(try ours.mainContext.fetchCount(FetchDescriptor<Account>()), 4)
        // Opening a profile again gives the same database, not a second one.
        XCTAssertTrue(stores.container(for: us) === ours)
    }

    func testSwitchingPointsPayAndSalarySettingsAtTheOpenProfile() throws {
        let stores = ProfileStores(defaults: try makeDefaults(), inMemory: true)
        Prefs.profile.set(16_500_000, forKey: Prefs.salary)
        defer { UserDefaults.standard.removeObject(forKey: Prefs.salary) }

        let us = try XCTUnwrap(try stores.add(name: "Us", swatch: 1).get())
        XCTAssertTrue(stores.select(us.id))
        XCTAssertFalse(Prefs.profile === UserDefaults.standard)
        XCTAssertEqual(Prefs.profile.integer(forKey: Prefs.salary), 0, "Us has its own salary setting")
        Prefs.profile.set(8_000_000, forKey: Prefs.salary)

        XCTAssertTrue(stores.select(ProfileRegistry.originalID))
        XCTAssertEqual(Prefs.profile.integer(forKey: Prefs.salary), 16_500_000)
        XCTAssertTrue(stores.select(us.id))
        XCTAssertEqual(Prefs.profile.integer(forKey: Prefs.salary), 8_000_000)
        ProfilePrefs.erase(us)
    }

    func testTheOpenProfileAndTheListAreRememberedNextLaunch() throws {
        let defaults = try makeDefaults()
        let first = ProfileStores(defaults: defaults, inMemory: true)
        let us = try XCTUnwrap(try first.add(name: "Us", swatch: 4).get())
        first.select(us.id)

        let second = ProfileStores(defaults: defaults, inMemory: true)
        XCTAssertEqual(second.profiles.map(\.name), ["Mine", "Us"])
        XCTAssertEqual(second.active.id, us.id)
        XCTAssertFalse(Prefs.profile === UserDefaults.standard, "settings follow the remembered profile")
        ProfilePrefs.erase(us)
    }

    func testDeletingAProfileRemovesItsDataAndItsSettingsAndNothingElse() throws {
        let stores = ProfileStores(defaults: try makeDefaults(), inMemory: true)
        let mine = stores.container(for: stores.active)
        mine.mainContext.insert(Transaction(type: .expense, amount: 1_000, note: "keep me", date: TestData.day(2026, 10, 1)))
        try mine.mainContext.save()

        let us = try XCTUnwrap(try stores.add(name: "Us", swatch: 1).get())
        _ = stores.container(for: us)
        ProfilePrefs.defaults(for: us).set(1, forKey: Prefs.salary)

        XCTAssertNil(stores.remove(us.id))
        XCTAssertEqual(stores.profiles.map(\.name), ["Mine"])
        XCTAssertNil(ProfilePrefs.defaults(for: us).object(forKey: Prefs.salary))
        XCTAssertEqual(try entries(mine).map(\.title), ["keep me"])
        XCTAssertEqual(stores.remove(stores.active.id), .cannotRemoveActive)
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
