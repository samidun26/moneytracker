import Foundation

/// The span between two paydays, and the "Tanggal Tua" battery that drains
/// across it. The battery rules come from the retro prototype
/// (design/prototype/Main.dc.html, `renderVals` → "Tanggal Tua"); the pay
/// period itself generalizes the prototype's single hard-coded month.
struct PayPeriod: Equatable {
    /// The most recent payday (inclusive start of this period).
    let start: Date
    /// The next payday — when the battery refills.
    let nextPayday: Date
    /// Days from today until the next payday, at least 1.
    let daysLeft: Int
}

enum PayCycle {
    /// A payday in a given month; days past the month's end clamp (31 → Feb 28).
    static func payday(year: Int, month: Int, day: Int) -> Date {
        let clamped = min(max(1, day), DateHelpers.daysInMonth(year: year, month: month))
        return DateHelpers.date(year: year, month: month, day: clamped)
    }

    static func period(today: Date, paydayDay: Int) -> PayPeriod {
        let today = DateHelpers.startOfDay(today)
        let thisMonth = MonthKey(today)
        let inThisMonth = payday(year: thisMonth.year, month: thisMonth.month, day: paydayDay)
        let start: Date
        let next: Date
        if inThisMonth <= today {
            start = inThisMonth
            let following = thisMonth.shifted(by: 1)
            next = payday(year: following.year, month: following.month, day: paydayDay)
        } else {
            let previous = thisMonth.shifted(by: -1)
            start = payday(year: previous.year, month: previous.month, day: paydayDay)
            next = inThisMonth
        }
        return PayPeriod(start: start, nextPayday: next, daysLeft: max(1, DateHelpers.diffDays(from: today, to: next)))
    }

    /// Expenses (never transfers) that fall inside the period.
    static func spent(_ entries: [Entry], in period: PayPeriod) -> Int {
        entries
            .filter { $0.type == .expense && $0.date >= period.start && $0.date < period.nextPayday }
            .reduce(0) { $0 + $1.amount }
    }
}

/// The Tanggal Tua battery: how much of the period's spending money is left,
/// and what that allows per day until payday.
struct Battery: Equatable {
    enum Level { case ok, warn, low }
    static let cellCount = 20

    let budget: Int
    let spent: Int
    let daysLeft: Int

    init(budget: Int, spent: Int, daysLeft: Int) {
        self.budget = budget
        self.spent = spent
        self.daysLeft = max(1, daysLeft)
    }

    private var limit: Int { max(1, budget) }
    var left: Int { budget - spent }

    /// 0...1
    var fraction: Double { max(0, min(1, Double(left) / Double(limit))) }
    var percent: Int { Int((fraction * 100).rounded()) }
    /// At 20% or less the app asks the user to spend gently.
    var isPowerSaving: Bool { fraction <= 0.2 }
    var allowance: Int { max(0, Int(floor(Double(left) / Double(daysLeft)))) }
    var filledCells: Int { Int((fraction * Double(Battery.cellCount)).rounded()) }

    var level: Level {
        if fraction <= 0.2 { return .low }
        if fraction <= 0.5 { return .warn }
        return .ok
    }

    /// "Rp 478.500 left for 7 days · payday Thu 1 Oct"
    func summary(payday: Date) -> String {
        let leftText = left >= 0 ? "\(CurrencyFormatter.formatRp(left)) left" : "Over by \(CurrencyFormatter.formatRp(-left))"
        let days = "\(daysLeft) \(daysLeft == 1 ? "day" : "days")"
        return "\(leftText) for \(days) · payday \(DateHelpers.formatPayday(payday))"
    }

    var accessibilityLabel: String {
        "Spending battery \(percent) percent. \(CurrencyFormatter.formatRp(allowance)) a day until payday."
    }
}
