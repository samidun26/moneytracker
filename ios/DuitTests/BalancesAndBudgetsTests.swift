import XCTest
@testable import Duit

/// Ported from src/domain/finance.test.ts (balances, month totals, budgets).
final class BalancesAndBudgetsTests: XCTestCase {
    private let a1 = UUID()
    private let a2 = UUID()
    private let a3 = UUID()
    private let sep = TestData.day(2026, 9, 24)

    private var accounts: [AccountRef] {
        [
            AccountRef(id: a1, name: "Cash", kind: .cash, openingBalance: 500_000),
            AccountRef(id: a2, name: "Card", kind: .credit, openingBalance: -200_000),
            AccountRef(id: a3, name: "Old", kind: .cash, openingBalance: 1_000, archived: true),
        ]
    }

    private var entries: [Entry] {
        [
            TestData.expense(50_000, on: sep, account: a1),
            TestData.income(1_000_000, on: sep, account: a1),
            TestData.transfer(200_000, from: a1, to: a2, on: sep),
        ]
    }

    func testBalancesIncludeTransfersAndSkipArchivedInNetWorth() {
        let b = Balances.byAccount(accounts, entries: entries)
        XCTAssertEqual(b[a1], 500_000 - 50_000 + 1_000_000 - 200_000)
        XCTAssertEqual(b[a2], 0)
        XCTAssertEqual(Balances.netWorth(accounts, balances: b), 1_250_000)
    }

    func testMonthTotalsExcludeTransfers() {
        let s = Balances.monthSummary(entries, month: MonthKey(sep))
        XCTAssertEqual(s, Balances.MonthSummary(income: 1_000_000, expense: 50_000, count: 2))
        XCTAssertEqual(s.net, 950_000)
        XCTAssertEqual(Balances.monthSummary(entries, month: MonthKey(TestData.day(2026, 8, 1))).count, 0)
    }

    func testBudgetStatusThresholds() {
        XCTAssertEqual(BudgetCalculator.status(ratio: 0.5), .ok)
        XCTAssertEqual(BudgetCalculator.status(ratio: 0.8), .warn)
        XCTAssertEqual(BudgetCalculator.status(ratio: 1), .warn)
        XCTAssertEqual(BudgetCalculator.status(ratio: 1.01), .over)
    }

    func testSpendingByCategoryAndOverall() {
        let food = UUID(), coffee = UUID()
        let list = [
            TestData.expense(400_000, on: sep, categoryID: food),
            TestData.expense(200_000, on: sep, categoryID: coffee),
            TestData.expense(999, on: TestData.day(2026, 8, 31), categoryID: food), // other month
            TestData.income(5_000_000, on: sep),
        ]
        let s = BudgetCalculator.spending(list, in: MonthKey(sep))
        XCTAssertEqual(s.byCategory[food], 400_000)
        XCTAssertEqual(s.byCategory[coffee], 200_000)
        XCTAssertEqual(s.total, 600_000)
    }

    func testProgressMeter() {
        let p = BudgetCalculator.progress(limit: 1_000_000, spent: 400_000)
        XCTAssertEqual(p.remaining, 600_000)
        XCTAssertEqual(p.status, .ok)
        XCTAssertEqual(p.filledBlocks, 8)
        XCTAssertEqual(BudgetCalculator.progress(limit: 1_000_000, spent: 850_000).status, .warn)
        let over = BudgetCalculator.progress(limit: 1_000_000, spent: 1_300_000)
        XCTAssertEqual(over.status, .over)
        XCTAssertEqual(over.filledBlocks, 20) // never more than the meter holds
        XCTAssertEqual(over.remaining, -300_000)
    }

    func testZeroLimitDoesNotCrash() {
        let p = BudgetCalculator.progress(limit: 0, spent: 5)
        XCTAssertEqual(p.status, .over)
        XCTAssertEqual(p.filledBlocks, 20)
        XCTAssertEqual(BudgetCalculator.progress(limit: 0, spent: 0).status, .ok)
    }
}
