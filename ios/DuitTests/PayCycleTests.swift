import XCTest
@testable import Duit

/// The prototype's own numbers (design/prototype/Main.dc.html): payday on
/// the 1st with today = Thu 24 Sep 2026 is 7 days away; Rp 11.521.500 spent
/// of a Rp 12.000.000 budget leaves Rp 478.500 — a 4% battery, Rp 68.357 a day.
final class PayCycleTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    func testPaydayOnTheFirst() {
        let p = PayCycle.period(today: day(2026, 9, 24), paydayDay: 1)
        XCTAssertEqual(p.start, day(2026, 9, 1))
        XCTAssertEqual(p.nextPayday, day(2026, 10, 1))
        XCTAssertEqual(p.daysLeft, 7)
    }

    func testPaydayOnThe25thIsTomorrow() {
        let p = PayCycle.period(today: day(2026, 9, 24), paydayDay: 25)
        XCTAssertEqual(p.start, day(2026, 8, 25))
        XCTAssertEqual(p.nextPayday, day(2026, 9, 25))
        XCTAssertEqual(p.daysLeft, 1)
    }

    func testPaydayOnThe28th() {
        let p = PayCycle.period(today: day(2026, 9, 24), paydayDay: 28)
        XCTAssertEqual(p.nextPayday, day(2026, 9, 28))
        XCTAssertEqual(p.daysLeft, 4)
    }

    func testOnPaydayItselfANewPeriodStarts() {
        let p = PayCycle.period(today: day(2026, 9, 25), paydayDay: 25)
        XCTAssertEqual(p.start, day(2026, 9, 25))
        XCTAssertEqual(p.nextPayday, day(2026, 10, 25))
        XCTAssertEqual(p.daysLeft, 30)
    }

    func testPaydayDay31ClampsInShortMonths() {
        let p = PayCycle.period(today: day(2027, 2, 10), paydayDay: 31)
        XCTAssertEqual(p.start, day(2027, 1, 31))
        XCTAssertEqual(p.nextPayday, day(2027, 2, 28))
        XCTAssertEqual(p.daysLeft, 18)
    }

    func testPeriodsCrossTheNewYear() {
        let a = PayCycle.period(today: day(2026, 12, 30), paydayDay: 1)
        XCTAssertEqual(a.start, day(2026, 12, 1))
        XCTAssertEqual(a.nextPayday, day(2027, 1, 1))
        XCTAssertEqual(a.daysLeft, 2)
        let b = PayCycle.period(today: day(2027, 1, 3), paydayDay: 25)
        XCTAssertEqual(b.start, day(2026, 12, 25))
        XCTAssertEqual(b.nextPayday, day(2027, 1, 25))
    }

    func testSpentCountsOnlyExpensesInsideThePeriod() {
        let period = PayPeriod(start: day(2026, 9, 1), nextPayday: day(2026, 10, 1), daysLeft: 7)
        let list = [
            TestData.expense(100_000, on: day(2026, 9, 1)), // first day counts
            TestData.expense(70_000, on: day(2026, 9, 30)),
            TestData.expense(50_000, on: day(2026, 8, 31)), // before
            TestData.expense(10_000, on: day(2026, 10, 1)), // next period
            TestData.income(1_000_000, on: day(2026, 9, 5)),
            TestData.transfer(200_000, from: UUID(), to: UUID(), on: day(2026, 9, 6)),
        ]
        XCTAssertEqual(PayCycle.spent(list, in: period), 170_000)
    }

    // MARK: Battery

    func testThePrototypesSampleBattery() {
        let b = Battery(budget: 12_000_000, spent: 11_521_500, daysLeft: 7)
        XCTAssertEqual(b.left, 478_500)
        XCTAssertEqual(b.percent, 4)
        XCTAssertEqual(b.allowance, 68_357)
        XCTAssertEqual(b.filledCells, 1)
        XCTAssertTrue(b.isPowerSaving)
        XCTAssertEqual(b.level, .low)
        XCTAssertEqual(b.summary(payday: day(2026, 10, 1)), "Rp 478.500 left for 7 days · payday Thu 1 Oct")
    }

    func testBatteryLevelsAtTheThresholds() {
        XCTAssertEqual(Battery(budget: 1000, spent: 0, daysLeft: 5).level, .ok)
        XCTAssertEqual(Battery(budget: 1000, spent: 490, daysLeft: 5).level, .ok) // 51%
        XCTAssertEqual(Battery(budget: 1000, spent: 500, daysLeft: 5).level, .warn) // 50%
        XCTAssertEqual(Battery(budget: 1000, spent: 800, daysLeft: 5).level, .low) // 20%
        XCTAssertFalse(Battery(budget: 1000, spent: 790, daysLeft: 5).isPowerSaving) // 21%
        XCTAssertEqual(Battery(budget: 1000, spent: 0, daysLeft: 5).filledCells, 20)
    }

    func testOverspentBatteryIsEmptyAndSaysSo() {
        let b = Battery(budget: 1_000_000, spent: 1_200_000, daysLeft: 3)
        XCTAssertEqual(b.fraction, 0)
        XCTAssertEqual(b.percent, 0)
        XCTAssertEqual(b.allowance, 0)
        XCTAssertEqual(b.filledCells, 0)
        XCTAssertEqual(b.summary(payday: day(2026, 10, 1)), "Over by Rp 200.000 for 3 days · payday Thu 1 Oct")
    }

    func testSingleDayWording() {
        let b = Battery(budget: 1_000_000, spent: 0, daysLeft: 1)
        XCTAssertTrue(b.summary(payday: day(2026, 9, 25)).contains("for 1 day ·"))
        XCTAssertEqual(Battery(budget: 1, spent: 0, daysLeft: 0).daysLeft, 1) // never divides by zero
    }

    func testBatteryWithNoBudgetDoesNotCrash() {
        let b = Battery(budget: 0, spent: 0, daysLeft: 5)
        XCTAssertEqual(b.allowance, 0)
        XCTAssertEqual(b.fraction, 0)
    }
}
