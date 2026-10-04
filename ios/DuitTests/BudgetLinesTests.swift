import XCTest
@testable import Duit

/// The Budgets window on Insights: overall first, then each category budget.
final class BudgetLinesTests: XCTestCase {
    private let food = UUID()
    private let transport = UUID()
    private let coffee = UUID()
    private lazy var categories: [(id: UUID, name: String)] = [
        (food, "Food & Drinks"), (transport, "Transport"), (coffee, "Coffee & Snacks"),
    ]

    private func spending(food f: Int = 0, transport t: Int = 0, coffee c: Int = 0) -> BudgetCalculator.Spending {
        var s = BudgetCalculator.Spending()
        s.byCategory = [food: f, transport: t, coffee: c]
        s.total = f + t + c
        return s
    }

    func testOverallComesFirstThenCategoriesInTheirOwnOrder() {
        let limits = [
            BudgetLimit(categoryID: coffee, amount: 300_000),
            BudgetLimit(categoryID: nil, amount: 12_000_000),
            BudgetLimit(categoryID: food, amount: 2_600_000),
        ]
        let lines = BudgetLines.lines(limits: limits, categories: categories, spending: spending(food: 1_000_000, coffee: 310_000))
        XCTAssertEqual(lines.map(\.label), ["Overall", "Food & Drinks", "Coffee & Snacks"])
        XCTAssertEqual(lines[0].progress.spent, 1_310_000)
        XCTAssertEqual(lines[1].progress.status, .ok)
        XCTAssertEqual(lines[2].progress.status, .over)
        XCTAssertEqual(lines[2].progress.remaining, -10_000)
    }

    func testZeroLimitsAndMissingCategoriesAreSkipped() {
        let limits = [
            BudgetLimit(categoryID: nil, amount: 0),
            BudgetLimit(categoryID: transport, amount: 0),
            BudgetLimit(categoryID: UUID(), amount: 500_000), // its category was deleted
        ]
        XCTAssertTrue(BudgetLines.lines(limits: limits, categories: categories, spending: spending()).isEmpty)
    }

    func testACategoryWithNoSpendingStartsAtZero() {
        let lines = BudgetLines.lines(
            limits: [BudgetLimit(categoryID: transport, amount: 1_300_000)],
            categories: categories,
            spending: BudgetCalculator.Spending()
        )
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].progress.spent, 0)
        XCTAssertEqual(lines[0].progress.filledBlocks, 0)
    }

    func testEachLineHasItsOwnStableId() {
        let lines = BudgetLines.lines(
            limits: [BudgetLimit(categoryID: nil, amount: 100), BudgetLimit(categoryID: food, amount: 100)],
            categories: categories,
            spending: spending()
        )
        XCTAssertEqual(Set(lines.map(\.id)).count, 2)
    }
}
