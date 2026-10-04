import XCTest
import SwiftData
@testable import Duit

/// Import end to end on the real (in-memory) SwiftData store, including the
/// promise behind "export, update the app, import": what comes out of one
/// store goes into another unchanged, and importing it twice adds nothing.
final class ImportWriterTests: XCTestCase {
    private lazy var container = Store.makeInMemoryContainer()
    private lazy var otherContainer = Store.makeInMemoryContainer()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    private func seeded(_ container: ModelContainer) throws -> ModelContext {
        let ctx = ModelContext(container)
        DefaultCategories.seedIfNeeded(ctx)
        DefaultAccounts.seedIfNeeded(ctx)
        try ctx.save()
        return ctx
    }

    private func entries(_ ctx: ModelContext) throws -> [Entry] {
        try ctx.fetch(FetchDescriptor<Transaction>()).map { Entry($0) }
    }

    private func wallets(_ ctx: ModelContext) throws -> [AccountRef] {
        try ctx.fetch(FetchDescriptor<Account>()).map { AccountRef($0) }
    }

    private func plan(_ text: String, into ctx: ModelContext, wallet: String = "Bank") throws -> ImportPlan {
        ImportPlan.make(
            file: try CSVImport.read(text).get(),
            existing: try entries(ctx),
            wallets: try wallets(ctx),
            defaultWallet: wallet
        )
    }

    // MARK: A bank statement

    func testAStatementIsAddedToTheChosenWalletWithOtherAsTheCategory() throws {
        let ctx = try seeded(container)
        let text = "Date,Description,Debit,Credit\n2025-10-01,KOPI,32000,\n2025-10-02,GAJI,,5000000\n"

        let committed = ImportWriter.commit(try plan(text, into: ctx), into: ctx)

        XCTAssertEqual(committed.ids.count, 2)
        XCTAssertTrue(committed.walletsCreated.isEmpty)
        let saved = try ctx.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(saved.map(\.amount), [32_000, 5_000_000])
        XCTAssertEqual(saved.map(\.type), [.expense, .income])
        XCTAssertEqual(saved.map { $0.account?.name }, ["Bank", "Bank"])
        XCTAssertEqual(saved.map { $0.category?.name }, ["Other", "Other"])
        XCTAssertEqual(saved.map { $0.category?.kind }, [.expense, .income])
        XCTAssertEqual(saved.map(\.note), ["KOPI", "GAJI"])
    }

    func testImportingTheSameStatementAgainAddsNothing() throws {
        let ctx = try seeded(container)
        let text = "Date,Description,Debit,Credit\n2025-10-01,KOPI,32000,\n2025-10-02,GAJI,,5000000\n"
        ImportWriter.commit(try plan(text, into: ctx), into: ctx)

        let again = try plan(text, into: ctx)

        XCTAssertTrue(again.items.isEmpty)
        XCTAssertEqual(again.duplicates, 2)
    }

    func testUndoRemovesOnlyWhatTheImportAdded() throws {
        let ctx = try seeded(container)
        ctx.insert(Transaction(type: .expense, amount: 1_000, note: "mine", date: day(2025, 9, 1)))
        try ctx.save()
        let text = "Date,Description,Debit,Credit\n2025-10-01,KOPI,32000,\n"

        let committed = ImportWriter.commit(try plan(text, into: ctx), into: ctx)
        XCTAssertEqual(try entries(ctx).count, 2)
        ImportWriter.remove(ids: committed.ids, from: ctx)

        XCTAssertEqual(try entries(ctx).map(\.title), ["mine"])
    }

    // MARK: The app's own export

    func testAnExportComesBackExactlyInANewStoreAndASecondImportAddsNothing() throws {
        // Store A: a few transactions, a worth-it answer, a wallet the other store lacks.
        let a = try seeded(container)
        let food = try XCTUnwrap(try a.fetch(FetchDescriptor<Duit.Category>()).first { $0.name == "Food & Drinks" })
        let salary = try XCTUnwrap(try a.fetch(FetchDescriptor<Duit.Category>()).first { $0.name == "Salary" })
        let cash = try XCTUnwrap(try a.fetch(FetchDescriptor<Account>()).first { $0.name == "Cash" })
        let bank = try XCTUnwrap(try a.fetch(FetchDescriptor<Account>()).first { $0.name == "Bank" })
        let gopay = Account(name: "GoPay", kind: .ewallet, order: 9)
        a.insert(gopay)
        a.insert(Transaction(type: .expense, amount: 52_000, category: food, note: "GrabFood, \"large\"", date: day(2026, 9, 21), account: gopay, rating: .regret))
        a.insert(Transaction(type: .expense, amount: 20_000, category: food, note: "Mie ayam", date: day(2026, 9, 21), account: cash))
        a.insert(Transaction(type: .expense, amount: 20_000, category: food, note: "Mie ayam", date: day(2026, 9, 21), account: cash))
        a.insert(Transaction(type: .income, amount: 16_500_000, category: salary, note: "Gaji", date: day(2026, 9, 1), account: bank, rating: nil))
        a.insert(Transaction(type: .transfer, amount: 400_000, note: "Top up", date: day(2026, 9, 20), account: bank, toAccount: gopay))
        try a.save()
        let original = try entries(a)
        let csv = CSVExport.csv(original)

        // Store B: a fresh install (default wallets and categories only).
        let b = try seeded(otherContainer)
        let first = try plan(csv, into: b, wallet: "Cash")
        XCTAssertEqual(first.newWallets, ["GoPay"])
        let committed = ImportWriter.commit(first, into: b)
        XCTAssertEqual(committed.walletsCreated, ["GoPay"])

        let restored = try entries(b)
        XCTAssertEqual(restored.count, original.count)
        for was in original {
            let now = try XCTUnwrap(restored.first { $0.id == was.id }, "\(was.title) lost its id")
            XCTAssertEqual(now.type, was.type)
            XCTAssertEqual(now.amount, was.amount)
            XCTAssertEqual(now.date, was.date)
            XCTAssertEqual(now.title, was.title)
            XCTAssertEqual(now.categoryName, was.categoryName)
            XCTAssertEqual(now.accountName, was.accountName)
            XCTAssertEqual(now.toAccountName, was.toAccountName)
            XCTAssertEqual(now.rating, was.rating)
        }
        // The new wallet got a type from its name.
        let created = try XCTUnwrap(try b.fetch(FetchDescriptor<Account>()).first { $0.name == "GoPay" })
        XCTAssertEqual(created.kind, .ewallet)

        // Importing the same file again, on this store or on the original, adds nothing.
        XCTAssertTrue(try plan(csv, into: b).items.isEmpty)
        XCTAssertEqual(try plan(csv, into: b).duplicates, original.count)
        XCTAssertTrue(try plan(csv, into: a).items.isEmpty)
    }

    func testRowsFromAnOlderExportWithoutIDsStillDoNotDoubleUp() throws {
        let ctx = try seeded(container)
        let old = """
        Date,Type,Amount,Signed amount,Category,Account,To account,Note
        2026-09-01,expense,50000,-50000,Food & Drinks,Cash,,Lunch
        """
        ImportWriter.commit(try plan(old, into: ctx), into: ctx)
        XCTAssertEqual(try entries(ctx).count, 1)
        XCTAssertEqual(try entries(ctx).first?.categoryName, "Food & Drinks")

        XCTAssertTrue(try plan(old, into: ctx).items.isEmpty)
    }
}
