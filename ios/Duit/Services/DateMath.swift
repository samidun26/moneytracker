import Foundation

/// The rest of the calendar math the retro screens need, ported from
/// src/lib/dates.ts (addDays, addMonthsClamped, monthBounds, ordinal,
/// weekdayName). Everything works on local calendar days, like DateHelpers.
extension DateHelpers {
    static func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? today()
    }

    static func year(of date: Date) -> Int { calendar.component(.year, from: date) }
    static func month(of date: Date) -> Int { calendar.component(.month, from: date) }
    static func day(of date: Date) -> Int { calendar.component(.day, from: date) }

    static func addDays(_ date: Date, _ days: Int) -> Date {
        startOfDay(calendar.date(byAdding: .day, value: days, to: date) ?? date)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        let first = self.date(year: year, month: month, day: 1)
        return calendar.range(of: .day, in: .month, for: first)?.count ?? 30
    }

    /// Adds months keeping the day-of-month (or `anchorDay`), clamped to the
    /// target month's length: Jan 31 + 1 month → Feb 28.
    static func addMonthsClamped(_ date: Date, _ months: Int, anchorDay: Int? = nil) -> Date {
        let total = year(of: date) * 12 + (month(of: date) - 1) + months
        let newYear = Int(floor(Double(total) / 12))
        let newMonth = total - newYear * 12 + 1
        let day = min(anchorDay ?? self.day(of: date), daysInMonth(year: newYear, month: newMonth))
        return self.date(year: newYear, month: newMonth, day: day)
    }

    /// "Monday"
    static func weekdayName(_ date: Date) -> String {
        weekdays[calendar.component(.weekday, from: date) - 1]
    }

    /// "Thu 1 Oct" — the prototype's payday format.
    static func formatPayday(_ date: Date) -> String {
        "\(weekdayName(date).prefix(3)) \(formatShortDate(date))"
    }

    /// 1 → "1st", 22 → "22nd", 13 → "13th"
    static func ordinal(_ n: Int) -> String {
        let lastTwo = n % 100
        if (11...13).contains(lastTwo) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }
}

/// A calendar month (src/lib/dates.ts `MonthKey`), comparable and shiftable.
struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int // 1...12

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(_ date: Date) {
        self.year = DateHelpers.year(of: date)
        self.month = DateHelpers.month(of: date)
    }

    static func < (a: MonthKey, b: MonthKey) -> Bool {
        (a.year, a.month) < (b.year, b.month)
    }

    func shifted(by delta: Int) -> MonthKey {
        let total = year * 12 + (month - 1) + delta
        let newYear = Int(floor(Double(total) / 12))
        return MonthKey(year: newYear, month: total - newYear * 12 + 1)
    }

    var start: Date { DateHelpers.date(year: year, month: month, day: 1) }
    var dayCount: Int { DateHelpers.daysInMonth(year: year, month: month) }
    var fullName: String { DateHelpers.months[month - 1] }
    var shortName: String { String(fullName.prefix(3)) }
}
