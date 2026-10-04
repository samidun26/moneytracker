import XCTest
import SwiftData
@testable import Duit

/// Payday Split, "Reset all data" and the wallet rules, on an in-memory store.
final class SettingsWritersTests: XCTestCase {
    private lazy var container = Store.makeInMemoryContainer()
    private let today = TestData.day(2026, 10, 3)

    private func seededContext() throws -> ModelContext {
        let ctx = ModelContext(container)
        DefaultCategories.seedIfNeeded(ctx)
        DefaultAccounts.seedIfNeeded(ctx)
        DefaultSplitBuckets.seedIfNeeded(ctx)
        try ctx.save()
        UserDefaults.standard.removeObject(forKey: Prefs.lastSplitPeriod)
        UserDefaults.standard.removeObject(forKey: Prefs.lastIncomeAccount)
        return ctx
    }

    private func ledger(_ ctx: ModelContext, salary: Int = 16_500_000) throws -> Ledger {
        Ledger(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()),
            accounts: try ctx.fetch(FetchDescriptor<Account>()),
            categories: try ctx.fetch(FetchDescriptor<Duit.Category>()),
            budgets: try ctx.fetch(FetchDescriptor<Budget>()),
            rules: try ctx.fetch(FetchDescriptor<RecurringRule>()),
            paydayDay: 1,
            salary: salary,
            today: today
        )
    }

    // MARK: Payday Split

    func testSplitLogsSalarySetsSpendingMoneyAndRemembersTheBuckets() throws {
        let ctx = try seededContext()
        let l = try ledger(ctx)
        let buckets = try ctx.fetch(FetchDescriptor<SplitBucket>(sortBy: [SortDescriptor(\.order)]))
        let plan = buckets.map { (id: $0.id, amount: 2_000_000) }
        let spending = PaydaySplit.spendingMoney(salary: 16_500_000, buckets: plan.map { $0.amount })
        XCTAssertEqual(spending, 8_500_000)

        let outcome = PaydayWriter.confirm(salary: 16_500_000, buckets: plan, spendingMoney: spending, ledger: l, in: ctx)

        XCTAssertNotNil(outcome.salaryTransactionID)
        let income = try ctx.fetch(FetchDescriptor<Transaction>()).filter { $0.type == .income }
        XCTAssertEqual(income.count, 1)
        XCTAssertEqual(income[0].amount, 16_500_000)
        XCTAssertEqual(income[0].category?.name, "Salary")
        XCTAssertEqual(income[0].account?.kind, .bank) // salary lands in the bank
        let overall = try ctx.fetch(FetchDescriptor<Budget>()).filter { $0.categoryID == nil }
        XCTAssertEqual(overall.map(\.amount), [8_500_000])
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SplitBucket>()).map(\.amount), [2_000_000, 2_000_000, 2_000_000, 2_000_000])
        XCTAssertEqual(UserDefaults.standard.double(forKey: Prefs.lastSplitPeriod), l.period.start.timeIntervalSince1970)
        XCTAssertFalse(try ledger(ctx).needsPaydaySplit)
    }

    func testSplitDoesNotLogTheSalaryTwice() throws {
        let ctx = try seededContext()
        let bank = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.kind == .bank })
        let salaryCategory = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Duit.Category>()).first { $0.name == "Salary" })
        ctx.insert(Transaction(type: .income, amount: 16_500_000, category: salaryCategory, note: "gaji", date: TestData.day(2026, 10, 1), account: bank))
        try ctx.save()

        let outcome = PaydayWriter.confirm(salary: 16_500_000, buckets: [], spendingMoney: 9_000_000, ledger: try ledger(ctx), in: ctx)

        XCTAssertNil(outcome.salaryTransactionID)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Budget>()).first?.amount, 9_000_000)
    }

    func testSplitUpdatesAnExistingOverallBudgetInPlace() throws {
        let ctx = try seededContext()
        ctx.insert(Budget(categoryID: nil, amount: 5_000_000))
        try ctx.save()
        PaydayWriter.confirm(salary: 10_000_000, buckets: [], spendingMoney: 6_000_000, ledger: try ledger(ctx, salary: 10_000_000), in: ctx)
        let budgets = try ctx.fetch(FetchDescriptor<Budget>())
        XCTAssertEqual(budgets.count, 1)
        XCTAssertEqual(budgets[0].amount, 6_000_000)
    }

    func testSplitRefusesNegativeSpendingMoney() throws {
        let ctx = try seededContext()
        let outcome = PaydayWriter.confirm(salary: 1_000_000, buckets: [], spendingMoney: -1, ledger: try ledger(ctx), in: ctx)
        XCTAssertNil(outcome.salaryTransactionID)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<Transaction>()).isEmpty)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<Budget>()).isEmpty)
    }

    // MARK: Reset

    func testResetEmptiesTheDataAndRestoresTheDefaults() throws {
        let ctx = try seededContext()
        let cash = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.kind == .cash })
        ctx.insert(Transaction(type: .expense, amount: 20_000, note: "mie ayam", date: today, account: cash))
        ctx.insert(Budget(categoryID: nil, amount: 5_000_000))
        ctx.insert(RecurringRule(amount: 186_000, note: "Netflix", startDate: today))
        ctx.insert(Account(name: "Extra", kind: .savings, order: 9))
        try ctx.save()
        UserDefaults.standard.set(16_500_000, forKey: Prefs.salary)

        DataReset.eraseEverything(in: ctx)

        XCTAssertTrue(try ctx.fetch(FetchDescriptor<Transaction>()).isEmpty)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<Budget>()).isEmpty)
        XCTAssertTrue(try ctx.fetch(FetchDescriptor<RecurringRule>()).isEmpty)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Account>()).map(\.name).sorted(), ["Bank", "Cash", "E-wallet"])
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Duit.Category>()), DefaultCategories.items.count)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<SplitBucket>()), DefaultSplitBuckets.items.count)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: Prefs.salary), 0)
    }

    // MARK: Wallet rules

    func testAWalletWithHistoryOrABillCannotBeDeleted() {
        let used = UUID(), target = UUID(), billed = UUID(), fresh = UUID()
        let entries = [
            TestData.expense(10_000, on: today, account: used),
            TestData.transfer(50_000, from: used, to: target, on: today),
        ]
        XCTAssertFalse(WalletRules.canDelete(used, entries: entries, ruleAccountIDs: []))
        XCTAssertFalse(WalletRules.canDelete(target, entries: entries, ruleAccountIDs: []))
        XCTAssertFalse(WalletRules.canDelete(billed, entries: entries, ruleAccountIDs: [billed]))
        XCTAssertTrue(WalletRules.canDelete(fresh, entries: entries, ruleAccountIDs: [billed]))
    }

    func testACreditCardOpeningBalanceIsWhatYouOwe() {
        XCTAssertEqual(WalletRules.storedOpening(entered: 1_500_000, kind: .credit), -1_500_000)
        XCTAssertEqual(WalletRules.storedOpening(entered: 1_500_000, kind: .bank), 1_500_000)
        XCTAssertEqual(WalletRules.enteredOpening(stored: -1_500_000, kind: .credit), 1_500_000)
        XCTAssertEqual(WalletRules.enteredOpening(stored: 250_000, kind: .cash), 250_000)
        XCTAssertEqual(WalletRules.enteredOpening(stored: 250_000, kind: .credit), 0)
    }
}
