import Foundation

enum BudgetStatus: Equatable {
    case ok, warn, over

    var label: String {
        switch self {
        case .ok: "On track"
        case .warn: "Careful"
        case .over: "Over"
        }
    }
}

/// Budget progress — a port of src/domain/budgets.ts (thresholds tested in
/// finance.test.ts) plus the prototype's 20-block meter.
enum BudgetCalculator {
    static let blockCount = 20

    static func status(ratio: Double) -> BudgetStatus {
        if ratio > 1 { return .over }
        if ratio >= 0.8 { return .warn }
        return .ok
    }

    struct Spending: Equatable {
        var byCategory: [UUID: Int] = [:]
        var uncategorized = 0
        var total = 0
    }

    /// Expense totals for a month, per category and overall.
    static func spending(_ entries: [Entry], in month: MonthKey) -> Spending {
        var s = Spending()
        for t in entries where t.type == .expense && MonthKey(t.date) == month {
            s.total += t.amount
            if let id = t.categoryID { s.byCategory[id, default: 0] += t.amount } else { s.uncategorized += t.amount }
        }
        return s
    }

    struct Progress: Equatable {
        let limit: Int
        let spent: Int
        var remaining: Int { limit - spent }
        var ratio: Double {
            limit > 0 ? Double(spent) / Double(limit) : (spent > 0 ? .infinity : 0)
        }
        var status: BudgetStatus { BudgetCalculator.status(ratio: ratio) }
        /// How many of the 20 meter blocks are lit.
        var filledBlocks: Int {
            ratio.isFinite ? min(BudgetCalculator.blockCount, Int((ratio * Double(BudgetCalculator.blockCount)).rounded())) : BudgetCalculator.blockCount
        }
        var percentUsed: Int { ratio.isFinite ? Int((ratio * 100).rounded()) : 999 }
    }

    static func progress(limit: Int, spent: Int) -> Progress {
        Progress(limit: limit, spent: spent)
    }
}
