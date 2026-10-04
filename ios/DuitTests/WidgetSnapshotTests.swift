import XCTest
@testable import Duit

/// What the widgets show, and how a widget tap finds its way into the app.
final class WidgetSnapshotTests: XCTestCase {
    private let today = TestData.day(2026, 10, 4)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    private func make(_ entries: [Entry], battery: Battery? = nil, hide: Bool = false) -> WidgetSnapshot {
        WidgetSnapshotBuilder.make(entries: entries, battery: battery, today: today, hideAmounts: hide, palette: "candy")
    }

    // MARK: Builder

    func testTodayAndMonthCountOnlyExpenses() {
        let snapshot = make([
            TestData.expense(32_000, on: day(2026, 10, 4)),
            TestData.expense(18_000, on: day(2026, 10, 4)),
            TestData.expense(500_000, on: day(2026, 10, 1)),
            TestData.expense(900_000, on: day(2026, 9, 30)), // last month
            TestData.expense(70_000, on: day(2026, 11, 2)), // a future-dated one
            TestData.income(16_500_000, on: day(2026, 10, 1)),
            TestData.transfer(100_000, from: UUID(), to: UUID(), on: day(2026, 10, 4)),
        ])
        XCTAssertEqual(snapshot.spentToday, 50_000)
        XCTAssertEqual(snapshot.spentMonth, 550_000)
        XCTAssertEqual(snapshot.day, today)
    }

    func testBatteryNumbersComeFromTheBattery() throws {
        let battery = Battery(budget: 12_000_000, spent: 3_000_000, daysLeft: 18)
        let snapshot = make([], battery: battery)
        XCTAssertEqual(try XCTUnwrap(snapshot.batteryFraction), 0.75, accuracy: 0.0001)
        XCTAssertEqual(snapshot.batteryPercent, 75)
        XCTAssertEqual(snapshot.batteryFilledCells, 15)
        XCTAssertEqual(snapshot.allowancePerDay, 500_000)
        XCTAssertEqual(snapshot.daysLeft, 18)
        XCTAssertEqual(snapshot.level, .ok)
        XCTAssertNil(make([]).batteryPercent) // no spending money set yet
    }

    func testTheBatteryLevelFollowsTheAppsThresholds() {
        func level(spent: Int) -> WidgetSnapshot.Level {
            make([], battery: Battery(budget: 1_000, spent: spent, daysLeft: 10)).level
        }
        XCTAssertEqual(level(spent: 400), .ok) // 60% left
        XCTAssertEqual(level(spent: 600), .warn) // 40% left
        XCTAssertEqual(level(spent: 800), .low) // 20% left
        XCTAssertEqual(level(spent: 1_500), .low) // overspent
    }

    func testHideAmountsAndPaletteAreCarriedAlong() {
        let snapshot = WidgetSnapshotBuilder.make(entries: [], battery: nil, today: today, hideAmounts: true, palette: "sunset")
        XCTAssertTrue(snapshot.hideAmounts)
        XCTAssertEqual(snapshot.palette, "sunset")
    }

    // MARK: Staleness

    func testAYesterdaysSnapshotShowsZeroForToday() {
        let snapshot = make([TestData.expense(40_000, on: day(2026, 10, 4)), TestData.expense(60_000, on: day(2026, 10, 2))])
        XCTAssertEqual(snapshot.spentToday(at: day(2026, 10, 4)), 40_000)
        XCTAssertEqual(snapshot.spentToday(at: day(2026, 10, 5)), 0)
        XCTAssertEqual(snapshot.spentMonth(at: day(2026, 10, 5)), 100_000)
        XCTAssertEqual(snapshot.spentMonth(at: day(2026, 11, 1)), 0) // a new month starts empty
    }

    // MARK: Storage

    func testASavedSnapshotComesBackUnchanged() throws {
        let suite = "duit.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertNil(WidgetSnapshot.load(from: defaults))
        let snapshot = make([TestData.expense(12_345, on: today)], battery: Battery(budget: 5_000_000, spent: 1_000_000, daysLeft: 9))
        snapshot.save(to: defaults)
        XCTAssertEqual(WidgetSnapshot.load(from: defaults), snapshot)
    }

    func testGarbageInTheSharedStoreIsIgnored() throws {
        let suite = "duit.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: WidgetSnapshot.storageKey)
        XCTAssertNil(WidgetSnapshot.load(from: defaults))
    }

    // MARK: Routes

    func testWidgetLinksOpenTheRightPlace() {
        XCTAssertEqual(AppRoute(url: AppRoute.addExpense.url), .addExpense)
        XCTAssertEqual(AppRoute(url: AppRoute.today.url), .today)
        XCTAssertEqual(AppRoute.addExpense.url.absoluteString, "duit://add")
        XCTAssertNil(AppRoute(url: URL(string: "duit://nowhere")!))
        XCTAssertNil(AppRoute(url: URL(string: "https://example.com/add")!))
    }
}
