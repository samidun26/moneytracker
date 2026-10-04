import Foundation

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all, out, income

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .out: "Money out"
        case .income: "Money in"
        }
    }
}

/// Search, filter and day-grouping for the Activity list — ported from the
/// prototype's `filtered` / `groups` (design/prototype/Main.dc.html).
enum ActivitySearch {
    /// Newest first: by day, then by when it was logged.
    static func newestFirst(_ entries: [Entry]) -> [Entry] {
        entries.sorted { $0.date != $1.date ? $0.date > $1.date : $0.createdAt > $1.createdAt }
    }

    /// A query matches the name, category or account words, or — if it's
    /// only digits — part of the amount ("32000", "32.000").
    static func matches(_ e: Entry, filter: ActivityFilter, query: String) -> Bool {
        switch filter {
        case .out where e.type != .expense: return false
        case .income where e.type != .income: return false
        default: break
        }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return true }
        let hay = [e.displayName, e.categoryName ?? "", e.accountName ?? "", e.toAccountName ?? ""]
            .joined(separator: " ")
            .lowercased()
        if hay.contains(q) { return true }
        let digits = q.filter { $0 != "." && !$0.isWhitespace }
        return !digits.isEmpty && digits.allSatisfy(\.isNumber) && String(e.amount).contains(digits)
    }

    struct DayGroup: Identifiable, Equatable {
        let date: Date
        var items: [Entry]
        var net: Int
        var id: Date { date }
    }

    /// Consecutive entries on the same day, with the day's net (income − expense;
    /// transfers don't count). Expects newest-first input.
    static func groups(_ entries: [Entry]) -> [DayGroup] {
        var out: [DayGroup] = []
        for e in entries {
            let day = DateHelpers.startOfDay(e.date)
            let delta: Int
            switch e.type {
            case .income: delta = e.amount
            case .expense: delta = -e.amount
            case .transfer: delta = 0
            }
            if var last = out.last, last.date == day {
                last.items.append(e)
                last.net += delta
                out[out.count - 1] = last
            } else {
                out.append(DayGroup(date: day, items: [e], net: delta))
            }
        }
        return out
    }
}
