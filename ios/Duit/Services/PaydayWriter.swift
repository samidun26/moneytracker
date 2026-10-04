import Foundation
import SwiftData

/// What "Split it!" does: log the salary (unless this pay period's salary is
/// already on the books), remember each bucket's amount for next month, make
/// the leftover the spending money that powers the battery, and note that
/// this period has been split so Today stops offering it.
enum PaydayWriter {
    struct Outcome: Equatable {
        /// The salary income that was logged; nil when it was already there.
        var salaryTransactionID: UUID?
    }

    /// Salary already logged since the period began (logged by hand).
    static func salaryAlreadyLogged(_ entries: [Entry], since start: Date) -> Bool {
        entries.contains { $0.type == .income && $0.categoryName == "Salary" && $0.date >= start }
    }

    @discardableResult
    static func confirm(
        salary: Int,
        buckets: [(id: UUID, amount: Int)],
        spendingMoney: Int,
        ledger: Ledger,
        in context: ModelContext
    ) -> Outcome {
        var outcome = Outcome()
        guard salary > 0, spendingMoney >= 0 else { return outcome }

        if !salaryAlreadyLogged(ledger.entries, since: ledger.period.start) {
            let lastIncome = AccountDefaults.read(Prefs.lastIncomeAccount)
            let tx = Transaction(
                type: .income,
                amount: salary,
                category: ledger.category(named: "Salary", kind: .income),
                note: "Salary",
                date: ledger.today,
                account: ledger.account(AccountDefaults.income(ledger.accountRefs, last: lastIncome))
            )
            context.insert(tx)
            outcome.salaryTransactionID = tx.id
        }

        let stored = (try? context.fetch(FetchDescriptor<SplitBucket>())) ?? []
        for bucket in buckets {
            stored.first { $0.id == bucket.id }?.amount = bucket.amount
        }

        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        if let overall = budgets.first(where: { $0.categoryID == nil }) {
            overall.amount = spendingMoney
        } else {
            context.insert(Budget(categoryID: nil, amount: spendingMoney))
        }

        try? context.save()
        UserDefaults.standard.set(ledger.period.start.timeIntervalSince1970, forKey: Prefs.lastSplitPeriod)
        return outcome
    }
}
