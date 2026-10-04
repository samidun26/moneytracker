import Foundation

/// The schedule of a repeating bill — a port of src/domain/recurring.ts
/// (tested by recurring.test.ts; see DuitTests/RecurrenceTests.swift).
/// Monthly and yearly schedules keep the start day, clamped to the length of
/// the month: a bill that starts on the 31st falls on the 28th in February.
struct Recurrence: Equatable {
    var frequency: Frequency
    var interval: Int
    var startDate: Date
    var endDate: Date?

    private static let maxSteps = 5000

    /// The n-th occurrence (0-based).
    func occurrence(at n: Int) -> Date {
        let every = max(1, interval)
        let anchor = DateHelpers.day(of: startDate)
        switch frequency {
        case .daily: return DateHelpers.addDays(startDate, n * every)
        case .weekly: return DateHelpers.addDays(startDate, n * 7 * every)
        case .monthly: return DateHelpers.addMonthsClamped(startDate, n * every, anchorDay: anchor)
        case .yearly: return DateHelpers.addMonthsClamped(startDate, n * 12 * every, anchorDay: anchor)
        }
    }

    /// A safe lower bound for the first occurrence after `date`, so long
    /// histories (a daily rule from years ago) are skipped quickly.
    private func indexNear(_ date: Date) -> Int {
        let days = DateHelpers.diffDays(from: startDate, to: date)
        if days <= 0 { return 0 }
        let every = Double(max(1, interval))
        let approx: Double
        switch frequency {
        case .daily: approx = Double(days) / every
        case .weekly: approx = Double(days) / (7 * every)
        case .monthly: approx = Double(days) / (31 * every)
        case .yearly: approx = Double(days) / (366 * every)
        }
        return max(0, Int(floor(approx)) - 1)
    }

    /// Occurrences in (after, until] — `after` exclusive, `until` inclusive —
    /// honoring the end date.
    func occurrences(after: Date?, until: Date, limit: Int = 400) -> [Date] {
        var out: [Date] = []
        var end = until
        if let endDate, endDate < until { end = endDate }
        var n = after.map(indexNear) ?? 0
        var steps = 0
        while steps < Recurrence.maxSteps && out.count < limit {
            defer {
                steps += 1
                n += 1
            }
            let d = occurrence(at: n)
            if d > end { break }
            if let after, d <= after { continue }
            out.append(d)
        }
        return out
    }

    func next(after: Date) -> Date? {
        occurrences(after: after, until: DateHelpers.date(year: 9999, month: 12, day: 31), limit: 1).first
    }

    /// Occurrences that are due (≤ today) and not yet posted or skipped.
    func due(lastPosted: Date?, today: Date, limit: Int = 400) -> [Date] {
        let after = lastPosted ?? DateHelpers.addDays(startDate, -1)
        return occurrences(after: after, until: today, limit: limit)
    }

    /// The next date it will fire, after anything already handled.
    func nextDue(lastPosted: Date?) -> Date? {
        next(after: lastPosted ?? DateHelpers.addDays(startDate, -1))
    }

    /// Normalized monthly cost, for "fixed costs per month" totals.
    func monthlyEquivalent(amount: Int) -> Int {
        let every = Double(max(1, interval))
        let perYear: Double
        switch frequency {
        case .daily: perYear = 365
        case .weekly: perYear = 52
        case .monthly: perYear = 12
        case .yearly: perYear = 1
        }
        return Int((Double(amount) * perYear / every / 12).rounded())
    }

    /// "Monthly on the 25th", "Every Monday", "Every 3 days"
    var summary: String {
        let every = max(1, interval)
        switch frequency {
        case .daily:
            return every == 1 ? "Every day" : "Every \(every) days"
        case .weekly:
            let day = DateHelpers.weekdayName(startDate)
            return every == 1 ? "Every \(day)" : "Every \(every) weeks on \(day)"
        case .monthly:
            let day = DateHelpers.ordinal(DateHelpers.day(of: startDate))
            return every == 1 ? "Monthly on the \(day)" : "Every \(every) months on the \(day)"
        case .yearly:
            let date = DateHelpers.formatShortDate(startDate)
            return every == 1 ? "Yearly on \(date)" : "Every \(every) years on \(date)"
        }
    }

    /// "<ruleID>|yyyy-MM-dd" — one transaction per rule per day, ever.
    static func occurrenceKey(ruleID: UUID, date: Date) -> String {
        let y = DateHelpers.year(of: date)
        let m = DateHelpers.month(of: date)
        let d = DateHelpers.day(of: date)
        return "\(ruleID.uuidString)|\(String(format: "%04ld-%02ld-%02ld", y, m, d))"
    }
}

/// A rule reduced to what scheduling needs.
struct RuleRef: Identifiable, Equatable {
    let id: UUID
    var recurrence: Recurrence
    var lastPostedDate: Date?
    var active: Bool
    var amount: Int
}

struct RuleOccurrence: Equatable {
    enum Status: Equatable { case due, upcoming }
    let ruleID: UUID
    let date: Date
    let status: Status
    let amount: Int
}

enum RecurringSchedule {
    /// Due items plus upcoming ones within the horizon, oldest first (bigger
    /// amounts first on the same day).
    static func upcoming(_ rules: [RuleRef], today: Date, horizonDays: Int) -> [RuleOccurrence] {
        let horizon = DateHelpers.addDays(today, horizonDays)
        var out: [RuleOccurrence] = []
        for rule in rules where rule.active {
            for date in rule.recurrence.due(lastPosted: rule.lastPostedDate, today: today, limit: 12) {
                out.append(RuleOccurrence(ruleID: rule.id, date: date, status: .due, amount: rule.amount))
            }
            for date in rule.recurrence.occurrences(after: today, until: horizon, limit: 12) {
                out.append(RuleOccurrence(ruleID: rule.id, date: date, status: .upcoming, amount: rule.amount))
            }
        }
        return out.sorted { $0.date != $1.date ? $0.date < $1.date : $0.amount > $1.amount }
    }
}
