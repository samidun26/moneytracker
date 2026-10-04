import XCTest
@testable import Duit

/// "Your Prices", the Habit Time Machine and the Worth-it rules, checked
/// against the prototype's own sample numbers.
final class PricesHabitsWorthTests: XCTestCase {
    private let today = TestData.day(2026, 9, 24)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    // MARK: Prices

    private var mieAyam: [Entry] {
        let prices = [(5, 15_000), (6, 16_000), (7, 18_000), (8, 18_000), (9, 20_000)]
        return prices.enumerated().map { index, p in
            TestData.expense(p.1, on: day(2026, p.0, 15), title: index.isMultiple(of: 2) ? "Mie Ayam" : "mie ayam", category: "Food & Drinks")
        }
    }

    func testAPriceRiseIsReadFromTheUsersOwnTitles() {
        let result = PriceTracker.rows(mieAyam, today: today)
        XCTAssertEqual(result.rows.count, 1)
        let row = result.rows[0]
        XCTAssertEqual(row.history, [15_000, 16_000, 18_000, 18_000, 20_000])
        XCTAssertEqual(row.first, 15_000)
        XCTAssertEqual(row.last, 20_000)
        XCTAssertEqual(row.percent, 33) // the prototype's "+33%"
        XCTAssertEqual(row.since, MonthKey(year: 2026, month: 5))
        XCTAssertEqual(row.barHeights, [17, 18, 20, 20, 22])
        XCTAssertEqual(result.basket, 33)
    }

    func testBasketIsTheAverageChange() {
        var list = mieAyam
        for (month, price) in [(5, 28_000), (6, 30_000), (7, 31_000)] {
            list.append(TestData.expense(price, on: day(2026, month, 3), title: "Kopi", category: "Coffee & Snacks"))
        }
        let result = PriceTracker.rows(list, today: today)
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows.map(\.percent).sorted(), [11, 33]) // 28k → 31k is +11%
        XCTAssertEqual(result.basket, 22)
    }

    func testNeedsThreePurchasesAcrossTwoMonths() {
        let twoOnly = [
            TestData.expense(10_000, on: day(2026, 8, 1), title: "Parkir"),
            TestData.expense(12_000, on: day(2026, 9, 1), title: "Parkir"),
        ]
        XCTAssertTrue(PriceTracker.rows(twoOnly, today: today).rows.isEmpty)
        let oneMonth = (1...4).map { TestData.expense(10_000 + $0, on: day(2026, 9, $0), title: "Bensin") }
        XCTAssertTrue(PriceTracker.rows(oneMonth, today: today).rows.isEmpty)
        XCTAssertEqual(PriceTracker.rows([], today: today).basket, 0)
    }

    func testLatestPriceLookup() {
        XCTAssertEqual(PriceTracker.latestPrice(containing: "mie ayam", entries: mieAyam), 20_000)
        XCTAssertNil(PriceTracker.latestPrice(containing: "sushi", entries: mieAyam))
    }

    // MARK: Habits

    func testFindsWhatYouBuyAgainAndAgain() {
        var list: [Entry] = []
        for i in 0..<16 { list.append(TestData.expense(32_000, on: day(2026, 8, 1 + i), title: "Kopi Kenangan")) }
        for i in 0..<4 { list.append(TestData.expense(20_000, on: day(2026, 8, 3 + i * 5), title: "Mie Ayam")) }
        for i in 0..<3 { list.append(TestData.expense(9_000, on: day(2026, 8, 4 + i), title: "Gorengan")) } // too few
        for i in 0..<5 { list.append(TestData.expense(186_000, on: day(2026, 8, 1 + i), title: "Netflix", recurring: true)) } // a bill

        let habits = HabitFinder.habits(list, today: today)
        XCTAssertEqual(habits.map(\.title), ["Kopi Kenangan", "Mie Ayam"])
        XCTAssertEqual(habits[0].perWeek, 2)
        XCTAssertEqual(habits[0].price, 32_000)
        XCTAssertEqual(habits[0].yearly, 3_328_000)
        XCTAssertEqual(habits[1].perWeek, 1)
    }

    func testOldPurchasesDoNotCountAsAHabit() {
        let old = (0..<6).map { TestData.expense(30_000, on: day(2026, 5, 1 + $0), title: "Kopi") }
        XCTAssertTrue(HabitFinder.habits(old, today: today).isEmpty)
    }

    func testTheTimeMachineMath() {
        let kopi = Habit(title: "Kopi Kenangan", categoryName: "Coffee & Snacks", perWeek: 5, price: 32_000)
        XCTAssertEqual(kopi.yearly, 8_320_000) // the prototype's "Rp 8,3 jt/yr"
        let fewer = HabitFinder.project(kopi, perWeek: 2)
        XCTAssertEqual(fewer.yearNew, 3_328_000)
        XCTAssertEqual(fewer.saved, 4_992_000)
        XCTAssertEqual(fewer.monthsToGoal, 8) // Rp 3 jt Bali trip
        XCTAssertEqual(HabitFinder.project(kopi, perWeek: 5).monthsToGoal, 0)
        let more = HabitFinder.project(kopi, perWeek: 7)
        XCTAssertEqual(more.saved, 8_320_000 - 11_648_000)
        XCTAssertEqual(more.monthsToGoal, 0)
    }

    // MARK: Worth it?

    func testOnlyBigTreatsFromRecentDaysAreAsked() {
        let jacket = TestData.expense(499_000, on: day(2026, 9, 23), title: "Uniqlo jacket", category: "Shopping")
        let list = [
            jacket,
            TestData.expense(50_000, on: day(2026, 9, 23), category: "Shopping"), // too small
            TestData.expense(500_000, on: day(2026, 9, 23), category: "Housing"), // not a treat
            TestData.expense(500_000, on: day(2026, 9, 24), category: "Shopping"), // today
            TestData.expense(500_000, on: day(2026, 9, 5), category: "Shopping"), // too old (19 days)
            TestData.expense(500_000, on: day(2026, 9, 20), category: "Shopping", rating: .worth), // already answered
            TestData.expense(500_000, on: day(2026, 9, 20), category: "Shopping", recurring: true), // a bill
        ]
        XCTAssertEqual(WorthIt.pending(list, today: today), [jacket])
    }

    func testMostRecentIsAskedFirst() {
        let a = TestData.expense(499_000, on: day(2026, 9, 23), category: "Shopping")
        let b = TestData.expense(850_000, on: day(2026, 9, 22), category: "Shopping")
        let c = TestData.expense(120_000, on: day(2026, 9, 21), category: "Entertainment")
        XCTAssertEqual(WorthIt.pending([c, b, a], today: today), [a, b, c])
    }

    func testWhenText() {
        XCTAssertEqual(WorthIt.whenText(day(2026, 9, 23), today: today), "bought yesterday")
        XCTAssertEqual(WorthIt.whenText(day(2026, 9, 21), today: today), "bought 3 days ago")
    }

    func testReportTotalsAndRegrets() {
        let list = [
            TestData.expense(499_000, on: day(2026, 9, 1), title: "Jacket", rating: .regret),
            TestData.expense(850_000, on: day(2026, 9, 2), title: "Keyboard", rating: .worth),
            TestData.expense(120_000, on: day(2026, 9, 3), title: "CGV", rating: .worth),
            TestData.expense(10_000, on: day(2026, 9, 4), title: "Unrated"),
        ]
        let r = WorthIt.report(list)
        XCTAssertEqual(r.worthTotal, 970_000)
        XCTAssertEqual(r.regretTotal, 499_000)
        XCTAssertEqual(r.regretTitles, ["Jacket"])
        XCTAssertTrue(r.anyRated)
        XCTAssertFalse(WorthIt.report([]).anyRated)
    }
}
