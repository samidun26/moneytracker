import XCTest
import SwiftData
@testable import Duit

/// The glue between the database and the screens: the Ledger snapshot (the
/// battery and the To do list), wallet defaults, and
/// bills that post themselves exactly once. Runs on an in-memory store.
final class LedgerAndWriterTests: XCTestCase {
    private lazy var container = Store.makeInMemoryContainer()
    private let today = TestData.day(2026, 9, 24)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    private func seededContext() throws -> ModelContext {
        let ctx = ModelContext(container)
        DefaultCategories.seedIfNeeded(ctx)
        DefaultAccounts.seedIfNeeded(ctx)
        try ctx.save()
        UserDefaults.standard.removeObject(forKey: Prefs.lastExpenseAccount)
        UserDefaults.standard.removeObject(forKey: Prefs.lastIncomeAccount)
        return ctx
    }

    private func ledger(_ ctx: ModelContext, payday: Int = 1) throws -> Ledger {
        Ledger(
            transactions: try ctx.fetch(FetchDescriptor<Transaction>()),
            accounts: try ctx.fetch(FetchDescriptor<Account>()),
            categories: try ctx.fetch(FetchDescriptor<Duit.Category>()),
            budgets: try ctx.fetch(FetchDescriptor<Budget>()),
            rules: try ctx.fetch(FetchDescriptor<RecurringRule>()),
            paydayDay: payday,
            salary: 0,
            today: today
        )
    }

    private func category(_ ctx: ModelContext, _ name: String) throws -> Duit.Category {
        try XCTUnwrap(try ctx.fetch(FetchDescriptor<Duit.Category>()).first { $0.name == name })
    }

    private func account(_ ctx: ModelContext, _ kind: AccountKind) throws -> Account {
        try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.kind == kind })
    }

    // MARK: Wallet defaults

    func testDefaultWalletsFollowTheKindOfEntry() {
        let cash = AccountRef(name: "Cash", kind: .cash)
        let bank = AccountRef(name: "BCA", kind: .bank)
        let wallet = AccountRef(name: "GoPay", kind: .ewallet)
        let all = [cash, bank, wallet]
        XCTAssertEqual(AccountDefaults.expense(all, last: nil), wallet.id) // spending starts in the e-wallet
        XCTAssertEqual(AccountDefaults.income(all, last: nil), bank.id) // income lands in the bank
        XCTAssertEqual(AccountDefaults.expense(all, last: cash.id), cash.id) // but the last one used wins
        XCTAssertEqual(AccountDefaults.expense([cash], last: nil), cash.id)
        XCTAssertNil(AccountDefaults.expense([], last: nil))
        let pair = AccountDefaults.transferPair(all)
        XCTAssertEqual(pair.from, bank.id)
        XCTAssertEqual(pair.to, wallet.id)
    }

    func testAnArchivedWalletIsNeverTheDefault() {
        let old = AccountRef(name: "Old", kind: .ewallet, archived: true)
        let cash = AccountRef(name: "Cash", kind: .cash)
        XCTAssertEqual(AccountDefaults.expense([old, cash], last: old.id), cash.id)
    }

    // MARK: Ledger

    func testTheBatteryFollowsTheSpendingMoneyAndThePayPeriod() throws {
        let ctx = try seededContext()
        ctx.insert(Budget(categoryID: nil, amount: 12_000_000))
        ctx.insert(Transaction(type: .expense, amount: 11_521_500, note: "this period", date: day(2026, 9, 10)))
        ctx.insert(Transaction(type: .expense, amount: 999_999, note: "last period", date: day(2026, 8, 31)))
        try ctx.save()

        let l = try ledger(ctx)
        let battery = try XCTUnwrap(l.battery)
        XCTAssertEqual(battery.left, 478_500) // the prototype's own sample
        XCTAssertEqual(battery.daysLeft, 7)
        XCTAssertEqual(battery.percent, 4)
        XCTAssertEqual(l.overallBudget, 12_000_000)
    }

    func testNoSpendingMoneyMeansNoBattery() throws {
        let ctx = try seededContext()
        ctx.insert(Budget(categoryID: UUID(), amount: 300_000)) // a category budget isn't the overall one
        try ctx.save()
        XCTAssertNil(try ledger(ctx).battery)
        XCTAssertNil(try ledger(ctx).overallBudget)
    }

    func testBalancesComeFromTheWallets() throws {
        let ctx = try seededContext()
        let bank = try account(ctx, .bank)
        let wallet = try account(ctx, .ewallet)
        bank.openingBalance = 1_000_000
        ctx.insert(Transaction(type: .transfer, amount: 400_000, note: "Top up", date: day(2026, 9, 20), account: bank, toAccount: wallet))
        ctx.insert(Transaction(type: .expense, amount: 32_000, note: "Kopi", date: day(2026, 9, 21), account: wallet))
        try ctx.save()

        let l = try ledger(ctx)
        XCTAssertEqual(l.balances[bank.id], 600_000)
        XCTAssertEqual(l.balances[wallet.id], 368_000)
    }

    func testTheTodoListOrdersLateBillsThenAQuestionThenUpcomingBills() throws {
        let ctx = try seededContext()
        let health = try category(ctx, "Health")
        let housing = try category(ctx, "Housing")
        let shopping = try category(ctx, "Shopping")
        ctx.insert(RecurringRule(amount: 150_000, category: health, note: "BPJS Kesehatan", startDate: day(2026, 9, 20)))
        ctx.insert(RecurringRule(amount: 3_500_000, category: housing, note: "Kos Tebet", startDate: day(2026, 9, 27)))
        ctx.insert(Transaction(type: .expense, amount: 499_000, category: shopping, note: "Uniqlo jacket", date: day(2026, 9, 23)))
        try ctx.save()

        let items = try ledger(ctx).todoItems()
        XCTAssertEqual(items.map(\.title), ["BPJS Kesehatan", "Uniqlo jacket, worth it?", "Kos Tebet"])
        XCTAssertTrue(items[0].late)
        XCTAssertEqual(items[0].sub, "Overdue 4 days · Rp 150.000")
        XCTAssertEqual(items[1].sub, "Rp 499.000 · bought yesterday")
        XCTAssertEqual(items[2].sub, "Due 27 Sep · in 3 days · Rp 3.500.000")
    }

    func testAutoPostBillsDoNotAppearInTheTodoList() throws {
        let ctx = try seededContext()
        ctx.insert(RecurringRule(amount: 186_000, note: "Netflix", startDate: day(2026, 9, 20), autoPost: true))
        try ctx.save()
        XCTAssertTrue(try ledger(ctx).todoItems().isEmpty)
    }

    func testAWalletThatHasNeverBeenCheckedGetsANudge() throws {
        let ctx = try seededContext()
        let cash = try account(ctx, .cash)
        for i in 0..<5 {
            ctx.insert(Transaction(type: .expense, amount: 10_000, note: "x\(i)", date: day(2026, 9, 1 + i), account: cash))
        }
        try ctx.save()

        let nudge = try XCTUnwrap(try ledger(ctx).todoItems().first)
        XCTAssertEqual(nudge.title, "Check Cash")
        XCTAssertEqual(nudge.sub, "Never checked")

        cash.lastCheckedAt = day(2026, 9, 20) // checked 4 days ago: leave it alone
        try ctx.save()
        XCTAssertTrue(try ledger(ctx).todoItems().isEmpty)

        cash.lastCheckedAt = day(2026, 9, 4) // 20 days ago
        try ctx.save()
        XCTAssertEqual(try ledger(ctx).todoItems().first?.sub, "Last checked 20 days ago")
    }

    func testTodayNeverCountsAsTheNextPayday() throws {
        let l = try ledger(try seededContext(), payday: 24) // payday is today
        XCTAssertEqual(l.period.start, today)
        XCTAssertEqual(l.period.daysLeft, 30)
    }

    func testRatingAndUndoingADelete() throws {
        let ctx = try seededContext()
        let tx = Transaction(type: .expense, amount: 499_000, note: "Jacket", date: day(2026, 9, 23))
        ctx.insert(tx)
        try ctx.save()

        EntryWriter.rate(id: tx.id, .regret, in: ctx)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Transaction>()).first?.rating, .regret)

        let snapshot = EntryWriter.Snapshot(tx)
        EntryWriter.delete(id: tx.id, in: ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Transaction>()), 0)
        EntryWriter.delete(id: tx.id, in: ctx) // deleting twice is harmless (Undo after an edit)

        snapshot.restore(into: ctx)
        let back = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Transaction>()).first)
        XCTAssertEqual(back.note, "Jacket")
        XCTAssertEqual(back.amount, 499_000)
        XCTAssertEqual(back.rating, .regret)
    }

    // MARK: Bills

    func testAutoBillsPostEveryMissedMonthOnceAndOnlyOnce() throws {
        let ctx = try seededContext()
        let bank = try account(ctx, .bank)
        ctx.insert(RecurringRule(amount: 386_000, account: bank, note: "IndiHome", startDate: day(2026, 6, 25), autoPost: true))
        try ctx.save()

        XCTAssertEqual(RecurringPoster.postDue(in: ctx, today: today), 3) // Jun 25, Jul 25, Aug 25
        XCTAssertEqual(RecurringPoster.postDue(in: ctx, today: today), 0) // never twice
        let posted = try ctx.fetch(FetchDescriptor<Transaction>()).sorted { $0.date < $1.date }
        XCTAssertEqual(posted.map(\.date), [day(2026, 6, 25), day(2026, 7, 25), day(2026, 8, 25)])
        XCTAssertTrue(posted.allSatisfy { $0.recurringID != nil && $0.account?.id == bank.id })
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<RecurringRule>()).first?.lastPostedDate, day(2026, 8, 25))

        XCTAssertEqual(RecurringPoster.postDue(in: ctx, today: day(2026, 9, 25)), 1) // the next one, when it's due
    }

    func testPaidLogsTheBillAndSkipDoesNot() throws {
        let ctx = try seededContext()
        let rule = RecurringRule(amount: 150_000, note: "BPJS", startDate: day(2026, 9, 20))
        let other = RecurringRule(amount: 99_000, note: "Gym", startDate: day(2026, 9, 21))
        ctx.insert(rule)
        ctx.insert(other)
        try ctx.save()

        RecurringPoster.markPaid(rule, on: day(2026, 9, 20), in: ctx)
        RecurringPoster.markPaid(rule, on: day(2026, 9, 20), in: ctx) // a double tap
        RecurringPoster.skip(other, on: day(2026, 9, 21), in: ctx)

        let all = try ctx.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.note, "BPJS")
        XCTAssertEqual(rule.lastPostedDate, day(2026, 9, 20))
        XCTAssertEqual(other.lastPostedDate, day(2026, 9, 21))
        XCTAssertTrue(try ledger(ctx).todoItems().isEmpty) // both are handled now
    }

    func testPausedRulesPostNothing() throws {
        let ctx = try seededContext()
        ctx.insert(RecurringRule(amount: 1, note: "Paused", startDate: day(2026, 6, 1), autoPost: true, active: false))
        try ctx.save()
        XCTAssertEqual(RecurringPoster.postDue(in: ctx, today: today), 0)
    }
}
