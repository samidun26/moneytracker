import Foundation

/// Calendar-day helpers for transaction dates. Month/weekday names are
/// hand-rolled English strings — not locale-formatted — because the app's
/// UI language is fixed to English regardless of device locale (see
/// docs/PRD.md §4: "Language: English UI. Numbers and dates still use
/// Indonesian conventions."). This mirrors src/lib/dates.ts's own comment:
/// "Hand-rolled (not Intl) so output is identical in Safari, Chrome and
/// Node" — using `DateFormatter`'s locale-based templates here would make
/// weekday/month names change with the device's language, which is not
/// what the reference app does.
///
/// Only what Add Transaction and Transaction History need is ported here
/// (including month dividers, since History groups by month too).
/// Budget/Insights-only helpers (shiftMonth, monthBounds, ordinal, timeAgo,
/// …) belong to that phase and aren't needed yet.
enum DateHelpers {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private static let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]
    private static let weekdays = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    /// Truncates a Date to its local calendar day (midnight).
    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func today() -> Date {
        startOfDay(Date())
    }

    /// `to` minus `from`, in whole calendar days (can be negative).
    static func diffDays(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day ?? 0
    }

    /// "24 Sep"
    static func formatShortDate(_ date: Date) -> String {
        let day = calendar.component(.day, from: date)
        let month = String(months[calendar.component(.month, from: date) - 1].prefix(3))
        return "\(day) \(month)"
    }

    static func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        calendar.component(.month, from: a) == calendar.component(.month, from: b)
            && calendar.component(.year, from: a) == calendar.component(.year, from: b)
    }

    /// "September 2026" — used for month dividers in Transaction History.
    static func formatMonth(_ date: Date) -> String {
        "\(months[calendar.component(.month, from: date) - 1]) \(calendar.component(.year, from: date))"
    }

    /// "Today", "Yesterday", "Tomorrow", or "Wed, 24 Sep" (adds the year if
    /// it's not the current one).
    static func formatDayLabel(_ date: Date, today: Date = today()) -> String {
        let diff = diffDays(from: today, to: date)
        switch diff {
        case 0: return "Today"
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        default: break
        }
        let weekday = String(weekdays[calendar.component(.weekday, from: date) - 1].prefix(3))
        let base = "\(weekday), \(formatShortDate(date))"
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: today)
        return sameYear ? base : "\(base) \(calendar.component(.year, from: date))"
    }
}
