import XCTest
@testable import Duit

final class DateHelpersTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDiffDays() {
        let a = date(2026, 9, 24)
        XCTAssertEqual(DateHelpers.diffDays(from: a, to: a), 0)
        XCTAssertEqual(DateHelpers.diffDays(from: a, to: date(2026, 9, 25)), 1)
        XCTAssertEqual(DateHelpers.diffDays(from: a, to: date(2026, 9, 23)), -1)
        // Crosses a month boundary.
        XCTAssertEqual(DateHelpers.diffDays(from: date(2026, 9, 30), to: date(2026, 10, 1)), 1)
    }

    func testFormatShortDate() {
        XCTAssertEqual(DateHelpers.formatShortDate(date(2026, 9, 24)), "24 Sep")
        XCTAssertEqual(DateHelpers.formatShortDate(date(2026, 1, 1)), "1 Jan")
    }

    func testFormatDayLabelRelativeToToday() {
        let today = date(2026, 9, 25)
        XCTAssertEqual(DateHelpers.formatDayLabel(today, today: today), "Today")
        XCTAssertEqual(DateHelpers.formatDayLabel(date(2026, 9, 24), today: today), "Yesterday")
        XCTAssertEqual(DateHelpers.formatDayLabel(date(2026, 9, 26), today: today), "Tomorrow")
    }
}
