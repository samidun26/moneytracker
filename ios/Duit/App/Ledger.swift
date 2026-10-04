import SwiftUI

/// One consistent, read-only picture of the user's data, built once per
/// refresh from the SwiftData queries. Every screen reads from this instead
/// of recomputing balances, the battery or the To do list on its own.
struct Ledger {
    let today: Date
    /// Newest first.
    let transactions: [Transaction]
    /// The same transactions as plain values, in the same order.
    let entries: [Entry]
    let accounts: [Account]
    let accountRefs: [AccountRef]
    let balances: [UUID: Int]
    let categories: [Category]
    let budgets: [Budget]
    let rules: [RecurringRule]
    let paydayDay: Int
    let salary: Int
    let period: PayPeriod
    /// The user's overall monthly "spending money", if set.
    let overallBudget: Int?
    /// nil until a spending budget is set.
    let battery: Battery?

    private let transactionIndex: [UUID: Transaction]

    init(
        transactions: [Transaction],
        accounts: [Account],
        categories: [Category],
        budgets: [Budget],
        rules: [RecurringRule],
        paydayDay: Int,
        salary: Int,
        today: Date = DateHelpers.today()
    ) {
        let sorted = transactions.sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
        let entries = sorted.map { Entry($0) }
        let ordered = accounts.sorted { $0.order < $1.order }
        let refs = ordered.map { AccountRef($0) }
        let payday = min(31, max(1, paydayDay))
        let period = PayCycle.period(today: today, paydayDay: payday)
        let overall = budgets.first { $0.categoryID == nil && $0.amount > 0 }?.amount

        self.today = today
        self.transactions = sorted
        self.entries = entries
        self.accounts = ordered
        self.accountRefs = refs
        self.balances = Balances.byAccount(refs, entries: entries)
        self.categories = categories
        self.budgets = budgets
        self.rules = rules
        self.paydayDay = payday
        self.salary = salary
        self.period = period
        self.overallBudget = overall
        self.battery = overall.map { Battery(budget: $0, spent: PayCycle.spent(entries, in: period), daysLeft: period.daysLeft) }
        self.transactionIndex = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Lookups

    func transaction(id: UUID) -> Transaction? { transactionIndex[id] }

    func account(_ id: UUID?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    var activeAccounts: [Account] { accounts.filter { !$0.archived } }
    var activeAccountRefs: [AccountRef] { accountRefs.filter { !$0.archived } }

    /// A category by its default name and kind; falls back to that kind's "Other".
    func category(named name: String?, kind: TransactionType) -> Category? {
        if let name, let match = categories.first(where: { $0.name == name && $0.kind == kind }) { return match }
        return categories.first { $0.name == "Other" && $0.kind == kind }
    }

    func categories(of kind: TransactionType) -> [Category] {
        categories.filter { $0.kind == kind }
    }

    var currentMonth: MonthKey { MonthKey(today) }

    /// This month's expenses.
    var monthExpenses: [Entry] {
        entries.filter { $0.type == .expense && MonthKey($0.date) == currentMonth }
    }

    /// Whether it's time to offer the Payday Split: salary is set, the period
    /// has just started (first week), and the user hasn't split it yet.
    var needsPaydaySplit: Bool {
        guard salary > 0 else { return false }
        let done = UserDefaults.standard.double(forKey: Prefs.lastSplitPeriod)
        guard done != period.start.timeIntervalSince1970 else { return false }
        return DateHelpers.diffDays(from: period.start, to: today) <= 6
    }

    // MARK: Terminal

    func parseContext() -> ParseContext {
        ParseContext(
            accounts: accountRefs,
            history: entries,
            defaultExpenseAccountID: AccountDefaults.expense(accountRefs, last: AccountDefaults.read(Prefs.lastExpenseAccount)),
            defaultIncomeAccountID: AccountDefaults.income(accountRefs, last: AccountDefaults.read(Prefs.lastIncomeAccount))
        )
    }

    func terminalContext() -> TerminalContext {
        let spending = monthExpenses
        var byCategory: [String: Int] = [:]
        for e in spending { byCategory[e.categoryName ?? "Uncategorized", default: 0] += e.amount }

        let allowanceLines: [String]
        if let b = battery {
            allowanceLines = [
                "\(CurrencyFormatter.formatRp(b.allowance)) a day for \(b.daysLeft) \(b.daysLeft == 1 ? "day" : "days") (battery \(b.percent)%).",
                "Payday: \(DateHelpers.formatPayday(period.nextPayday)).",
            ]
        } else {
            allowanceLines = ["Set your spending money in Settings to start the battery."]
        }

        let prices = PriceTracker.rows(entries, today: today)
        let inflationLines: [String]
        if let top = prices.rows.max(by: { $0.percent < $1.percent }) {
            inflationLines = [
                "Your basket: \(prices.basket >= 0 ? "+" : "")\(prices.basket)% in 12 months.",
                "Biggest jump: \(top.title) \(top.percent >= 0 ? "+" : "")\(top.percent)%.",
            ]
        } else {
            inflationLines = ["Not enough repeated purchases yet. Log the same thing a few times."]
        }

        return TerminalContext(
            monthName: currentMonth.fullName,
            totalSpent: spending.reduce(0) { $0 + $1.amount },
            spentByCategory: byCategory,
            categoryNames: categories(of: .expense).map(\.name),
            expenses: spending.map { (title: $0.displayName, amount: $0.amount) },
            allowanceLines: allowanceLines,
            inflationLines: inflationLines
        )
    }

    // MARK: To do

    struct TodoItem: Identifiable {
        enum Kind {
            case bill(ruleID: UUID, date: Date)
            case worth(transactionID: UUID)
            case balance(accountID: UUID)
        }

        let id: String
        let order: Int
        let kind: Kind
        let icon: PixelRects?
        let emoji: String
        let color: Color
        let title: String
        let sub: String
        let late: Bool
    }

    /// Bills (late first), a "worth it?" question, a balance-check nudge, then
    /// upcoming bills — the prototype's single To do list.
    func todoItems() -> [TodoItem] {
        var items: [TodoItem] = []

        // Bills the user confirms by hand (auto-post bills log themselves).
        let remind = rules.filter { $0.active && !$0.autoPost }
        let refs = remind.map { RuleRef(id: $0.id, recurrence: $0.recurrence, lastPostedDate: $0.lastPostedDate, active: $0.active, amount: $0.amount) }
        for occurrence in RecurringSchedule.upcoming(refs, today: today, horizonDays: 7) {
            guard let rule = remind.first(where: { $0.id == occurrence.ruleID }) else { continue }
            let days = DateHelpers.diffDays(from: today, to: occurrence.date)
            let short = DateHelpers.formatShortDate(occurrence.date)
            let when: String
            switch days {
            case ..<(-1): when = "Overdue \(-days) days"
            case -1: when = "Due yesterday"
            case 0: when = "Due today"
            case 1: when = "Due \(short) · tomorrow"
            default: when = "Due \(short) · in \(days) days"
            }
            let name = rule.note.isEmpty ? (rule.category?.name ?? "Bill") : rule.note
            items.append(TodoItem(
                id: "bill-\(Recurrence.occurrenceKey(ruleID: rule.id, date: occurrence.date))",
                order: days < 0 ? 0 : 3,
                kind: .bill(ruleID: rule.id, date: occurrence.date),
                icon: CategoryPixelIcon.rects(for: rule.category?.icon ?? ""),
                emoji: rule.category?.icon ?? "📦",
                color: (rule.category?.color ?? .gray).color,
                title: name,
                sub: "\(when) · \(CurrencyFormatter.formatRp(rule.amount))",
                late: days < 0
            ))
        }

        // One "worth it?" question at a time, most recent purchase first.
        if let entry = WorthIt.pending(entries, today: today).first {
            items.append(TodoItem(
                id: "worth-\(entry.id.uuidString)",
                order: 1,
                kind: .worth(transactionID: entry.id),
                icon: CategoryPixelIcon.rects(for: entry.categoryIcon ?? ""),
                emoji: entry.categoryIcon ?? "📦",
                color: (entry.categoryColor ?? .gray).color,
                title: "\(entry.displayName), worth it?",
                sub: "\(CurrencyFormatter.formatRp(entry.amount)) · \(WorthIt.whenText(entry.date, today: today))",
                late: false
            ))
        }

        // Nudge to compare one well-used wallet with its real app.
        if let nudge = balanceNudge() {
            items.append(nudge)
        }

        return items.sorted { $0.order < $1.order }
    }

    private func balanceNudge() -> TodoItem? {
        var best: (account: Account, days: Int, count: Int)?
        for a in activeAccounts {
            let count = entries.filter { $0.accountID == a.id || $0.toAccountID == a.id }.count
            guard count >= 5 else { continue }
            let days = a.lastCheckedAt.map { DateHelpers.diffDays(from: $0, to: today) } ?? Int.max
            guard days >= 14 else { continue }
            if let current = best, (current.days, current.count) >= (days, count) { continue }
            best = (a, days, count)
        }
        guard let pick = best else { return nil }
        let sub = pick.days == Int.max ? "Never checked" : "Last checked \(pick.days) days ago"
        return TodoItem(
            id: "balance-\(pick.account.id.uuidString)",
            order: 2,
            kind: .balance(accountID: pick.account.id),
            icon: pick.account.kind.icon,
            emoji: "",
            color: pick.account.color.color,
            title: "Check \(pick.account.name)",
            sub: sub,
            late: false
        )
    }
}
