import XCTest
import SwiftData
@testable import Duit

/// Runs the real SwiftData schema (in memory): the new models, the new
/// optional fields on Transaction, the seeding and the legacy backfill.
final class StoreTests: XCTestCase {
    /// Kept alive for the whole test: a context must not outlive its container.
    private lazy var container = Store.makeInMemoryContainer()

    private func makeContext() -> ModelContext {
        ModelContext(container)
    }

    func testAllModelsAreRegistered() {
        XCTAssertEqual(Store.modelTypes.count, 6)
    }

    func testANewTransactionCarriesItsWalletRatingAndRecurrence() throws {
        let ctx = makeContext()
        let wallet = Account(name: "GoPay", kind: .ewallet, openingBalance: 100_000)
        let food = Duit.Category(name: "Food & Drinks", icon: "🍜", color: .orange, kind: .expense, order: 0)
        let ruleID = UUID()
        ctx.insert(wallet)
        ctx.insert(food)
        ctx.insert(Transaction(
            type: .expense, amount: 52_000, category: food, note: "GrabFood",
            date: TestData.day(2026, 9, 23), account: wallet, rating: .regret,
            recurringID: ruleID, occurrenceKey: "k"
        ))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(fetched.count, 1)
        let entry = Entry(fetched[0])
        XCTAssertEqual(entry.accountName, "GoPay")
        XCTAssertEqual(entry.categoryName, "Food & Drinks")
        XCTAssertEqual(entry.rating, .regret)
        XCTAssertTrue(entry.isRecurring)
        XCTAssertEqual(entry.title, "GrabFood")
        XCTAssertEqual(entry.displayName, "GrabFood")
    }

    func testTransfersStoreBothWalletsAndMoveTheBalances() throws {
        let ctx = makeContext()
        let bank = Account(name: "Bank", kind: .bank, openingBalance: 1_000_000)
        let wallet = Account(name: "GoPay", kind: .ewallet)
        ctx.insert(bank)
        ctx.insert(wallet)
        ctx.insert(Transaction(type: .transfer, amount: 600_000, note: "Top up", date: TestData.day(2026, 9, 22), account: bank, toAccount: wallet))
        try ctx.save()

        let entries = try ctx.fetch(FetchDescriptor<Transaction>()).map { Entry($0) }
        let refs = [AccountRef(bank), AccountRef(wallet)]
        let balances = Balances.byAccount(refs, entries: entries)
        XCTAssertEqual(balances[bank.id], 400_000)
        XCTAssertEqual(balances[wallet.id], 600_000)
        XCTAssertEqual(entries[0].toAccountName, "GoPay")
        XCTAssertEqual(Balances.netWorth(refs, balances: balances), 1_000_000)
    }

    func testSeedingIsIdempotent() throws {
        let ctx = makeContext()
        for _ in 0..<2 {
            DefaultCategories.seedIfNeeded(ctx)
            DefaultAccounts.seedIfNeeded(ctx)
            DefaultSplitBuckets.seedIfNeeded(ctx)
            try ctx.save()
        }
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Duit.Category>()), DefaultCategories.items.count)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Account>()), 3)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<SplitBucket>()), 4)
        let kinds = try ctx.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)])).map(\.kind)
        XCTAssertEqual(kinds, [.cash, .bank, .ewallet])
    }

    func testTransactionsFromBeforeWalletsEndUpInCash() throws {
        let ctx = makeContext()
        // How a transaction looked in the first release: no wallet at all.
        ctx.insert(Transaction(type: .expense, amount: 25_000, note: "old", date: TestData.day(2026, 9, 1)))
        DefaultAccounts.seedIfNeeded(ctx)
        DefaultAccounts.backfillLegacyTransactions(ctx)
        try ctx.save()
        let t = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        XCTAssertEqual(t.account?.name, "Cash")
    }

    func testBackfillLeavesExistingWalletsAlone() throws {
        let ctx = makeContext()
        DefaultAccounts.seedIfNeeded(ctx)
        let accounts = try ctx.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.order)]))
        let bank = try XCTUnwrap(accounts.first { $0.kind == .bank })
        ctx.insert(Transaction(type: .income, amount: 1, date: TestData.day(2026, 9, 1), account: bank))
        DefaultAccounts.backfillLegacyTransactions(ctx)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).first?.account?.kind, .bank)
    }

    func testBillsAndBudgetsRoundTrip() throws {
        let ctx = makeContext()
        let rule = RecurringRule(
            type: .expense, amount: 150_000, note: "BPJS Kesehatan", frequency: .monthly,
            startDate: TestData.day(2026, 6, 25), autoPost: false
        )
        ctx.insert(rule)
        ctx.insert(Budget(categoryID: nil, amount: 12_000_000))
        try ctx.save()

        let rules = try ctx.fetch(FetchDescriptor<RecurringRule>())
        XCTAssertEqual(rules.first?.recurrence.summary, "Monthly on the 25th")
        let budgets = try ctx.fetch(FetchDescriptor<Budget>())
        XCTAssertNil(budgets.first?.categoryID)
        XCTAssertEqual(budgets.first?.amount, 12_000_000)
    }

    func testDeletingAWalletKeepsItsTransactions() throws {
        let ctx = makeContext()
        let wallet = Account(name: "Old card", kind: .credit)
        ctx.insert(wallet)
        ctx.insert(Transaction(type: .expense, amount: 5_000, date: TestData.day(2026, 9, 1), account: wallet))
        try ctx.save()
        ctx.delete(wallet)
        try ctx.save()
        let remaining = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertNil(remaining[0].account)
    }
}
