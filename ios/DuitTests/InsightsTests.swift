import XCTest
@testable import Duit

/// Ported from src/domain/finance.test.ts (insights) plus the prototype's
/// chart scale and units.
final class InsightsTests: XCTestCase {
    private let food = UUID()
    private let coffee = UUID()
    private let sep = TestData.day(2026, 9, 24)

    private var entries: [Entry] {
        [
            TestData.expense(300_000, on: sep, category: "Food & Drinks", categoryID: food),
            TestData.expense(100_000, on: sep, category: "Coffee & Snacks", categoryID: coffee),
            TestData.expense(200_000, on: TestData.day(2026, 8, 5), category: "Food & Drinks", categoryID: food),
            TestData.income(9_000_000, on: TestData.day(2026, 8, 25)),
        ]
    }

    func testBreakdownSortsBiggestFirstWithPreviousMonth() {
        let slices = Insights.categoryBreakdown(entries, month: MonthKey(sep))
        XCTAssertEqual(slices.map(\.categoryID), [food, coffee])
        XCTAssertEqual(slices.map(\.amount), [300_000, 100_000])
        XCTAssertEqual(slices.map(\.share), [0.75, 0.25])
        XCTAssertEqual(slices.map(\.previous), [200_000, 0])
        XCTAssertEqual(slices.first?.name, "Food & Drinks")
        XCTAssertEqual(slices.first?.count, 1)
    }

    func testBreakdownOfIncome() {
        let slices = Insights.categoryBreakdown(entries, month: MonthKey(TestData.day(2026, 8, 1)), kind: .income)
        XCTAssertEqual(slices.map(\.amount), [9_000_000])
        XCTAssertEqual(slices.first?.name, "Uncategorized")
    }

    func testSixMonthTrendEndsAtTheSelectedMonth() {
        let t = Insights.monthlyTrend(entries, endMonth: MonthKey(sep), months: 6)
        XCTAssertEqual(t.count, 6)
        XCTAssertEqual(t[0].month, MonthKey(year: 2026, month: 4))
        XCTAssertEqual(t[4], Insights.TrendPoint(month: MonthKey(year: 2026, month: 8), income: 9_000_000, expense: 200_000))
        XCTAssertEqual(t[5].expense, 400_000)
    }

    func testTrendIgnoresTransfers() {
        let list = [TestData.transfer(500_000, from: UUID(), to: UUID(), on: sep)]
        let t = Insights.monthlyTrend(list, endMonth: MonthKey(sep), months: 3)
        XCTAssertEqual(t.map(\.expense), [0, 0, 0])
        XCTAssertEqual(t.map(\.income), [0, 0, 0])
    }

    func testDailyAverageUsesElapsedDays() {
        XCTAssertEqual(Insights.dailyAverage(expense: 240_000, month: MonthKey(sep), today: sep), 10_000)
        XCTAssertEqual(Insights.dailyAverage(expense: 310_000, month: MonthKey(TestData.day(2026, 8, 1)), today: sep), 10_000)
        XCTAssertEqual(Insights.dailyAverage(expense: 1, month: MonthKey(TestData.day(2026, 10, 1)), today: sep), 0)
    }

    func testMonthKeyShiftsAcrossYears() {
        XCTAssertEqual(MonthKey(year: 2026, month: 1).shifted(by: -1), MonthKey(year: 2025, month: 12))
        XCTAssertEqual(MonthKey(year: 2026, month: 11).shifted(by: 3), MonthKey(year: 2027, month: 2))
        XCTAssertTrue(MonthKey(year: 2025, month: 12) < MonthKey(year: 2026, month: 1))
    }

    // MARK: Chart scale

    func testNiceMax() {
        XCTAssertEqual(Insights.niceMax(0), 1, accuracy: 0.0001)
        XCTAssertEqual(Insights.niceMax(19_000_000), 20_000_000, accuracy: 0.0001)
        XCTAssertEqual(Insights.niceMax(13_900_000), 15_000_000, accuracy: 0.0001)
        XCTAssertEqual(Insights.niceMax(100), 100, accuracy: 0.0001)
        XCTAssertEqual(Insights.niceMax(101), 120, accuracy: 0.0001)
    }

    // MARK: Units

    func testQuantityFormatting() {
        XCTAssertEqual(Insights.formatQuantity(12.4), "12")
        XCTAssertEqual(Insights.formatQuantity(3.26), "3,3")
        XCTAssertEqual(Insights.formatQuantity(0.5), "0,5")
    }

    func testMieAyamBowls() {
        XCTAssertEqual(Insights.inUnit(480_000, unit: .mie, bowlPrice: 20_000, hourPrice: 0), "24 bowls")
        XCTAssertEqual(Insights.inUnit(20_000, unit: .mie, bowlPrice: 20_000, hourPrice: 0), "1 bowl")
        XCTAssertEqual(Insights.inUnit(10_000, unit: .mie, bowlPrice: 20_000, hourPrice: 0), "0,5 bowls")
    }

    func testWorkHours() {
        XCTAssertEqual(Insights.hourPrice(salary: 16_500_000), 95_376)
        XCTAssertEqual(Insights.hourPrice(salary: 0), 0)
        XCTAssertEqual(Insights.inUnit(5_000_000, unit: .hours, bowlPrice: 0, hourPrice: 95_376), "52 work hrs")
    }

    func testUnitsFallBackToRupiahWithoutAPrice() {
        XCTAssertEqual(Insights.inUnit(150_000, unit: .mie, bowlPrice: 0, hourPrice: 0), "150.000")
        XCTAssertEqual(Insights.lcdText(150_000, unit: .hours, bowlPrice: 0, hourPrice: 0), "150.000")
        XCTAssertEqual(
            Insights.lcdText(11_521_500, unit: .rupiah, bowlPrice: 0, hourPrice: 0),
            CurrencyFormatter.formatRpCompact(11_521_500)
        )
    }
}
