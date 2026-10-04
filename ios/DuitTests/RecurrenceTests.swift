import XCTest
@testable import Duit

/// Ported case-for-case from src/domain/recurring.test.ts.
final class RecurrenceTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    private func monthly(_ start: Date, end: Date? = nil) -> Recurrence {
        Recurrence(frequency: .monthly, interval: 1, startDate: start, endDate: end)
    }

    func testMonthlyKeepsTheAnchorDayAcrossShortMonths() {
        let r = monthly(day(2026, 1, 31))
        XCTAssertEqual(
            r.occurrences(after: nil, until: day(2026, 5, 31)),
            [day(2026, 1, 31), day(2026, 2, 28), day(2026, 3, 31), day(2026, 4, 30), day(2026, 5, 31)]
        )
    }

    func testDueOccurrencesAreTheOnesAfterTheLastHandled() {
        let r = monthly(day(2026, 6, 25))
        XCTAssertEqual(r.due(lastPosted: day(2026, 7, 25), today: day(2026, 9, 24)), [day(2026, 8, 25)])
        XCTAssertEqual(r.nextDue(lastPosted: day(2026, 7, 25)), day(2026, 8, 25))
    }

    func testEndDateStopsTheSchedule() {
        let r = monthly(day(2026, 1, 1), end: day(2026, 3, 15))
        XCTAssertEqual(r.due(lastPosted: nil, today: day(2026, 12, 31)), [day(2026, 1, 1), day(2026, 2, 1), day(2026, 3, 1)])
    }

    func testWeeklyIntervals() {
        let w = Recurrence(frequency: .weekly, interval: 2, startDate: day(2026, 9, 1), endDate: nil)
        XCTAssertEqual(w.occurrences(after: day(2026, 9, 1), until: day(2026, 10, 1)), [day(2026, 9, 15), day(2026, 9, 29)])
    }

    func testLongDailyHistoriesAreSkippedQuickly() {
        let d = Recurrence(frequency: .daily, interval: 1, startDate: day(2020, 1, 1), endDate: nil)
        XCTAssertEqual(
            d.occurrences(after: day(2026, 9, 20), until: day(2026, 9, 23)),
            [day(2026, 9, 21), day(2026, 9, 22), day(2026, 9, 23)]
        )
    }

    func testYearlyOnFeb29() {
        let y = Recurrence(frequency: .yearly, interval: 1, startDate: day(2028, 2, 29), endDate: nil)
        XCTAssertEqual(
            y.occurrences(after: nil, until: day(2033, 1, 1)),
            [day(2028, 2, 29), day(2029, 2, 28), day(2030, 2, 28), day(2031, 2, 28), day(2032, 2, 29)]
        )
    }

    func testMonthlyEquivalent() {
        XCTAssertEqual(Recurrence(frequency: .yearly, interval: 1, startDate: day(2026, 1, 1), endDate: nil).monthlyEquivalent(amount: 120_000), 10_000)
        XCTAssertEqual(Recurrence(frequency: .weekly, interval: 1, startDate: day(2026, 1, 1), endDate: nil).monthlyEquivalent(amount: 100_000), 433_333)
    }

    func testPlainEnglishSummaries() {
        XCTAssertEqual(monthly(day(2026, 9, 25)).summary, "Monthly on the 25th")
        XCTAssertEqual(Recurrence(frequency: .weekly, interval: 1, startDate: day(2026, 9, 21), endDate: nil).summary, "Every Monday")
        XCTAssertEqual(Recurrence(frequency: .daily, interval: 3, startDate: day(2026, 9, 1), endDate: nil).summary, "Every 3 days")
        XCTAssertEqual(Recurrence(frequency: .yearly, interval: 1, startDate: day(2026, 9, 24), endDate: nil).summary, "Yearly on 24 Sep")
    }

    func testOrdinals() {
        XCTAssertEqual(DateHelpers.ordinal(1), "1st")
        XCTAssertEqual(DateHelpers.ordinal(2), "2nd")
        XCTAssertEqual(DateHelpers.ordinal(3), "3rd")
        XCTAssertEqual(DateHelpers.ordinal(11), "11th")
        XCTAssertEqual(DateHelpers.ordinal(12), "12th")
        XCTAssertEqual(DateHelpers.ordinal(22), "22nd")
        XCTAssertEqual(DateHelpers.ordinal(25), "25th")
    }

    func testDueAndUpcomingAreListedInDateOrder() {
        let a = RuleRef(id: UUID(), recurrence: monthly(day(2026, 9, 20)), lastPostedDate: nil, active: true, amount: 150_000)
        let b = RuleRef(id: UUID(), recurrence: monthly(day(2026, 9, 27)), lastPostedDate: nil, active: true, amount: 3_500_000)
        let items = RecurringSchedule.upcoming([b, a], today: day(2026, 9, 24), horizonDays: 7)
        XCTAssertEqual(items.map(\.ruleID), [a.id, b.id])
        XCTAssertEqual(items.map(\.date), [day(2026, 9, 20), day(2026, 9, 27)])
        XCTAssertEqual(items.map(\.status), [.due, .upcoming])
    }

    func testPausedRulesAreIgnored() {
        let paused = RuleRef(id: UUID(), recurrence: monthly(day(2026, 9, 20)), lastPostedDate: nil, active: false, amount: 1)
        XCTAssertTrue(RecurringSchedule.upcoming([paused], today: day(2026, 9, 24), horizonDays: 7).isEmpty)
    }

    func testSkippedOrPaidOccurrencesDisappear() {
        let handled = RuleRef(id: UUID(), recurrence: monthly(day(2026, 9, 20)), lastPostedDate: day(2026, 9, 20), active: true, amount: 1)
        XCTAssertTrue(RecurringSchedule.upcoming([handled], today: day(2026, 9, 24), horizonDays: 7).isEmpty)
    }

    func testOccurrenceKeysAreStablePerRuleAndDay() {
        let id = UUID()
        let key = Recurrence.occurrenceKey(ruleID: id, date: day(2026, 9, 5))
        XCTAssertEqual(key, "\(id.uuidString)|2026-09-05")
        XCTAssertEqual(key, Recurrence.occurrenceKey(ruleID: id, date: day(2026, 9, 5)))
        XCTAssertNotEqual(key, Recurrence.occurrenceKey(ruleID: id, date: day(2026, 10, 5)))
    }
}
