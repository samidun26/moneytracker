import Foundation

/// A budget's limit as a plain value (a `Budget` without the database).
struct BudgetLimit: Equatable {
    /// nil = the overall "spending money" budget.
    let categoryID: UUID?
    let amount: Int
}

/// One row of the Insights Budgets window: a label and how much of the
/// limit this month's spending has used.
struct BudgetLine: Identifiable, Equatable {
    /// The category's id; nil for the overall budget.
    let categoryID: UUID?
    let label: String
    let progress: BudgetCalculator.Progress
    var id: String { categoryID?.uuidString ?? "overall" }
}

enum BudgetLines {
    static let overallLabel = "Overall"

    /// The overall budget first, then category budgets in the order the
    /// categories are listed. A limit of zero means "no budget", and a
    /// budget whose category no longer exists is skipped.
    static func lines(
        limits: [BudgetLimit],
        categories: [(id: UUID, name: String)],
        spending: BudgetCalculator.Spending
    ) -> [BudgetLine] {
        var lines: [BudgetLine] = []
        if let overall = limits.first(where: { $0.categoryID == nil && $0.amount > 0 }) {
            lines.append(BudgetLine(
                categoryID: nil,
                label: overallLabel,
                progress: BudgetCalculator.progress(limit: overall.amount, spent: spending.total)
            ))
        }
        for category in categories {
            guard let limit = limits.first(where: { $0.categoryID == category.id && $0.amount > 0 }) else { continue }
            lines.append(BudgetLine(
                categoryID: category.id,
                label: category.name,
                progress: BudgetCalculator.progress(limit: limit.amount, spent: spending.byCategory[category.id] ?? 0)
            ))
        }
        return lines
    }
}
