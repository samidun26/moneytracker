import Foundation

/// Works out what the widgets should show from the user's transactions.
/// Pure (no database, no WidgetKit) so it's unit-tested; WidgetSync writes
/// the result where the widgets can read it.
enum WidgetSnapshotBuilder {
    static func make(
        entries: [Entry],
        battery: Battery?,
        today: Date,
        hideAmounts: Bool,
        palette: String
    ) -> WidgetSnapshot {
        let day = DateHelpers.startOfDay(today)
        let month = MonthKey(today)
        let monthStart = month.start
        let nextMonthStart = month.shifted(by: 1).start
        var spentToday = 0
        var spentMonth = 0
        for e in entries where e.type == .expense {
            if e.date >= monthStart && e.date < nextMonthStart { spentMonth += e.amount }
            if DateHelpers.startOfDay(e.date) == day { spentToday += e.amount }
        }
        return WidgetSnapshot(
            day: day,
            spentToday: spentToday,
            spentMonth: spentMonth,
            batteryFraction: battery?.fraction,
            allowancePerDay: battery?.allowance,
            daysLeft: battery?.daysLeft,
            hideAmounts: hideAmounts,
            palette: palette
        )
    }
}
