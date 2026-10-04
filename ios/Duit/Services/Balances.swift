import Foundation

/// Account balances and month totals — a port of src/domain/balances.ts
/// (tested by finance.test.ts; see DuitTests/BalancesTests.swift).
enum Balances {
    /// Balance per account = opening balance + income − expense ± transfers.
    static func byAccount(_ accounts: [AccountRef], entries: [Entry]) -> [UUID: Int] {
        var balances: [UUID: Int] = [:]
        for a in accounts { balances[a.id] = a.openingBalance }
        func add(_ id: UUID?, _ delta: Int) {
            if let id { balances[id, default: 0] += delta }
        }
        for t in entries {
            switch t.type {
            case .expense:
                add(t.accountID, -t.amount)
            case .income:
                add(t.accountID, t.amount)
            case .transfer:
                add(t.accountID, -t.amount)
                add(t.toAccountID, t.amount)
            }
        }
        return balances
    }

    static func netWorth(_ accounts: [AccountRef], balances: [UUID: Int]) -> Int {
        accounts.filter { !$0.archived }.reduce(0) { $0 + (balances[$1.id] ?? 0) }
    }

    struct MonthSummary: Equatable {
        var income: Int
        var expense: Int
        var count: Int
        var net: Int { income - expense }
    }

    /// Transfers move money between your own accounts, so they're excluded.
    static func monthSummary(_ entries: [Entry], month: MonthKey) -> MonthSummary {
        var summary = MonthSummary(income: 0, expense: 0, count: 0)
        for t in entries where MonthKey(t.date) == month && t.type != .transfer {
            summary.count += 1
            if t.type == .income { summary.income += t.amount } else { summary.expense += t.amount }
        }
        return summary
    }
}
