import XCTest
@testable import Duit

final class DateMathTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    func testAddDays() {
        XCTAssertEqual(DateHelpers.addDays(day(2026, 9, 30), 1), day(2026, 10, 1))
        XCTAssertEqual(DateHelpers.addDays(day(2026, 1, 1), -1), day(2025, 12, 31))
    }

    func testAddMonthsClampsToTheMonthLength() {
        XCTAssertEqual(DateHelpers.addMonthsClamped(day(2026, 1, 31), 1), day(2026, 2, 28))
        XCTAssertEqual(DateHelpers.addMonthsClamped(day(2028, 1, 31), 1), day(2028, 2, 29)) // leap year
        XCTAssertEqual(DateHelpers.addMonthsClamped(day(2026, 11, 15), 3), day(2027, 2, 15))
        XCTAssertEqual(DateHelpers.addMonthsClamped(day(2026, 3, 31), -1), day(2026, 2, 28))
        XCTAssertEqual(DateHelpers.addMonthsClamped(day(2026, 2, 28), 1, anchorDay: 31), day(2026, 3, 31))
    }

    func testDaysInMonth() {
        XCTAssertEqual(DateHelpers.daysInMonth(year: 2026, month: 2), 28)
        XCTAssertEqual(DateHelpers.daysInMonth(year: 2028, month: 2), 29)
        XCTAssertEqual(DateHelpers.daysInMonth(year: 2026, month: 9), 30)
    }

    func testWeekdaysAndTheNextPaydayLabel() {
        XCTAssertEqual(DateHelpers.weekdayName(day(2026, 9, 21)), "Monday")
        XCTAssertEqual(DateHelpers.formatPayday(day(2026, 10, 1)), "Thu 1 Oct")
        XCTAssertEqual(DateHelpers.formatPayday(day(2026, 9, 25)), "Fri 25 Sep")
    }

    func testMonthKeyNamesAndSize() {
        let sep = MonthKey(day(2026, 9, 24))
        XCTAssertEqual(sep.fullName, "September")
        XCTAssertEqual(sep.shortName, "Sep")
        XCTAssertEqual(sep.dayCount, 30)
        XCTAssertEqual(sep.start, day(2026, 9, 1))
    }
}
