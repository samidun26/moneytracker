import Foundation

// "Your Prices" and the "Habit Time Machine". The prototype shows sample
// data; here both are read from the user's own transactions, using the same
// idea: the things you buy again and again, found by their titles.

// MARK: - Your Prices

struct PriceRow: Equatable {
    let title: String
    let categoryName: String?
    /// One price per month, oldest first (the last price logged that month).
    let history: [Int]
    var first: Int { history.first ?? 0 }
    var last: Int { history.last ?? 0 }
    /// Change from the first to the latest price, in percent.
    var percent: Int {
        first > 0 ? Int((Double(last - first) / Double(first) * 100).rounded()) : 0
    }
    /// Heights (3...22) for the last six prices, for the tiny bar chart.
    var barHeights: [Int] {
        let recent = Array(history.suffix(6))
        guard let top = recent.max(), top > 0 else { return [] }
        return recent.map { max(3, Int((Double($0) / Double(top) * 22).rounded())) }
    }
}

enum PriceTracker {
    static let minimumPurchases = 3
    static let maximumRows = 5

    /// Items bought at least 3 times across at least 2 different months in
    /// the last 12, most-bought first, plus the average change ("basket").
    static func rows(_ entries: [Entry], today: Date) -> (rows: [PriceRow], basket: Int) {
        let cutoff = DateHelpers.addMonthsClamped(today, -12)
        var groups: [String: [Entry]] = [:]
        for t in entries where t.type == .expense && !t.title.isEmpty && t.date >= cutoff && t.date <= today {
            groups[t.title.lowercased(), default: []].append(t)
        }
        var rows: [(count: Int, row: PriceRow)] = []
        for (_, items) in groups where items.count >= minimumPurchases {
            let ordered = items.sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
            var perMonth: [MonthKey: Int] = [:]
            for t in ordered { perMonth[MonthKey(t.date)] = t.amount }
            guard perMonth.count >= 2, let latest = ordered.last else { continue }
            let history = perMonth.keys.sorted().compactMap { perMonth[$0] }
            guard let first = history.first, first > 0 else { continue }
            rows.append((items.count, PriceRow(title: latest.title, categoryName: latest.categoryName, history: history)))
        }
        let top = rows
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.row.title < $1.row.title }
            .prefix(maximumRows)
            .map { $0.row }
        let basket = top.isEmpty ? 0 : Int((Double(top.reduce(0) { $0 + $1.percent }) / Double(top.count)).rounded())
        return (Array(top), basket)
    }

    /// The most recent price of anything whose title contains `term`.
    static func latestPrice(containing term: String, entries: [Entry]) -> Int? {
        let needle = term.lowercased()
        return entries
            .filter { $0.type == .expense && $0.title.lowercased().contains(needle) }
            .max { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }?
            .amount
    }
}

// MARK: - Habit Time Machine

struct Habit: Identifiable, Equatable {
    let title: String
    let categoryName: String?
    /// Roughly how many times a week it's bought.
    let perWeek: Int
    /// The typical (median) price.
    let price: Int
    var id: String { title.lowercased() }
    var yearly: Int { perWeek * price * 52 }
}

struct HabitProjection: Equatable {
    let yearNow: Int
    let yearNew: Int
    var saved: Int { yearNow - yearNew }
    /// Months of that saving it would take to reach the goal (0 if nothing saved).
    let monthsToGoal: Int
}

enum HabitFinder {
    static let lookbackWeeks = 8
    static let minimumPurchases = 4
    static let maximumHabits = 3
    /// The prototype's example goal: a trip to Bali.
    static let goal = 3_000_000

    /// Titles bought at least 4 times in the last 8 weeks, biggest yearly cost first.
    static func habits(_ entries: [Entry], today: Date) -> [Habit] {
        let cutoff = DateHelpers.addDays(today, -lookbackWeeks * 7)
        var groups: [String: [Entry]] = [:]
        for t in entries where t.type == .expense && !t.isRecurring && !t.title.isEmpty && t.date > cutoff && t.date <= today {
            groups[t.title.lowercased(), default: []].append(t)
        }
        var habits: [Habit] = []
        for (_, items) in groups where items.count >= minimumPurchases {
            let amounts = items.map(\.amount).sorted()
            let latest = items.max { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) } ?? items[0]
            habits.append(Habit(
                title: latest.title,
                categoryName: latest.categoryName,
                perWeek: max(1, Int((Double(items.count) / Double(lookbackWeeks)).rounded())),
                price: amounts[amounts.count / 2]
            ))
        }
        return habits
            .sorted { $0.yearly != $1.yearly ? $0.yearly > $1.yearly : $0.title < $1.title }
            .prefix(maximumHabits)
            .map { $0 }
    }

    /// What a year costs if the habit changes to `perWeek` times a week.
    static func project(_ habit: Habit, perWeek: Int) -> HabitProjection {
        let yearNew = perWeek * habit.price * 52
        let saved = habit.yearly - yearNew
        let months = saved > 0 ? Int(ceil(Double(goal) / (Double(saved) / 12))) : 0
        return HabitProjection(yearNow: habit.yearly, yearNew: yearNew, monthsToGoal: months)
    }
}

// MARK: - Worth it?

/// Which purchases to ask "worth it?" about, and the report of the answers.
enum WorthIt {
    static let minimumAmount = 100_000
    static let askWithinDays = 14
    /// Only treats-and-splurges get asked about, not rent or groceries.
    static let categoryNames: Set<String> = ["Shopping", "Entertainment", "Travel", "Gifts & Charity"]

    /// Unrated purchases from 1 to 14 days ago, most recent first.
    static func pending(_ entries: [Entry], today: Date) -> [Entry] {
        entries
            .filter { t in
                guard t.type == .expense, t.rating == nil, !t.isRecurring, t.amount >= minimumAmount,
                      let name = t.categoryName, categoryNames.contains(name) else { return false }
                let age = DateHelpers.diffDays(from: t.date, to: today)
                return age >= 1 && age <= askWithinDays
            }
            .sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
    }

    /// "bought yesterday", "bought 3 days ago"
    static func whenText(_ date: Date, today: Date) -> String {
        let age = DateHelpers.diffDays(from: date, to: today)
        if age <= 0 { return "bought today" }
        return age == 1 ? "bought yesterday" : "bought \(age) days ago"
    }

    struct Report: Equatable {
        var worthTotal = 0
        var regretTotal = 0
        var regretTitles: [String] = []
        var anyRated = false
    }

    static func report(_ entries: [Entry]) -> Report {
        var r = Report()
        for t in entries where t.type == .expense {
            guard let rating = t.rating else { continue }
            r.anyRated = true
            switch rating {
            case .worth:
                r.worthTotal += t.amount
            case .regret:
                r.regretTotal += t.amount
                r.regretTitles.append(t.displayName)
            }
        }
        return r
    }
}
