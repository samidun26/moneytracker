import XCTest
@testable import Duit

final class ImportPlanTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    private let bank = AccountRef(name: "Bank", kind: .bank)
    private let cash = AccountRef(name: "Cash", kind: .cash)

    private func row(
        _ n: Int, _ date: Date, _ amount: Int, _ title: String = "", type: TransactionType = .expense,
        account: String? = nil, to: String? = nil, category: String? = nil, id: UUID? = nil
    ) -> ImportRow {
        ImportRow(row: n, date: date, type: type, amount: amount, title: title, categoryName: category,
                  accountName: account, toAccountName: to, rating: nil, id: id)
    }

    private func statement(_ rows: [ImportRow], guessed: Bool = false) -> ImportFile {
        ImportFile(kind: .statement, rows: rows, problems: [], directionIsGuessed: guessed)
    }

    private func duit(_ rows: [ImportRow]) -> ImportFile {
        ImportFile(kind: .duit, rows: rows, problems: [], directionIsGuessed: false)
    }

    // MARK: Duplicates

    func testAStatementRowMatchingSomethingAlreadyLoggedIsSkippedWhateverItsWording() {
        let existing = [TestData.expense(32_000, on: day(2025, 10, 1), title: "Kopi", accountName: "Bank")]
        let file = statement([
            row(2, day(2025, 10, 1), 32_000, "QRIS KOPI KENANGAN"),
            row(3, day(2025, 10, 1), 20_000, "WARTEG"),
        ])
        let plan = ImportPlan.make(file: file, existing: existing, wallets: [bank], defaultWallet: "Bank")
        XCTAssertEqual(plan.duplicates, 1)
        XCTAssertEqual(plan.items.map(\.row.title), ["WARTEG"])
    }

    func testTwoRealPurchasesOnOneDayStayTwoUnlessYouAlreadyHaveThem() {
        let rows = [
            row(2, day(2025, 10, 1), 20_000, "MIE AYAM"),
            row(3, day(2025, 10, 1), 20_000, "MIE AYAM"),
        ]
        let none = ImportPlan.make(file: statement(rows), existing: [], wallets: [bank], defaultWallet: "Bank")
        XCTAssertEqual(none.items.count, 2)

        let one = [TestData.expense(20_000, on: day(2025, 10, 1), title: "Mie ayam", accountName: "Bank")]
        let half = ImportPlan.make(file: statement(rows), existing: one, wallets: [bank], defaultWallet: "Bank")
        XCTAssertEqual(half.items.count, 1)
        XCTAssertEqual(half.duplicates, 1)

        let both = one + one
        let all = ImportPlan.make(file: statement(rows), existing: both, wallets: [bank], defaultWallet: "Bank")
        XCTAssertEqual(all.items.count, 0)
        XCTAssertEqual(all.duplicates, 2)
    }

    func testTheSameDayAndAmountInAnotherWalletIsNotADuplicate() {
        let existing = [TestData.expense(32_000, on: day(2025, 10, 1), title: "Kopi", accountName: "Cash")]
        let file = statement([row(2, day(2025, 10, 1), 32_000, "KOPI")])
        let plan = ImportPlan.make(file: file, existing: existing, wallets: [bank, cash], defaultWallet: "Bank")
        XCTAssertEqual(plan.items.count, 1)
    }

    func testADuitExportIsMatchedByIDFirstThenByTheWholeRow() {
        let known = Entry(type: .expense, amount: 50_000, date: day(2026, 9, 1), title: "Lunch", accountName: "Cash")
        let file = duit([
            row(2, day(2026, 9, 1), 50_000, "Lunch", account: "Cash", id: known.id),            // same id
            row(3, day(2026, 9, 1), 50_000, "lunch ", account: "cash", id: UUID()),             // same row, other id
            row(4, day(2026, 9, 1), 50_000, "Dinner", account: "Cash", id: UUID()),             // different title: new
            row(5, day(2026, 9, 2), 10_000, "Parking", account: "Cash", id: nil),               // an old export: no id
        ])
        let plan = ImportPlan.make(file: file, existing: [known], wallets: [cash], defaultWallet: nil)
        XCTAssertEqual(plan.duplicates, 2)
        XCTAssertEqual(plan.items.map(\.row.title), ["Dinner", "Parking"])
    }

    func testTheSameIDTwiceInOneFileIsAddedOnce() {
        let id = UUID()
        let file = duit([
            row(2, day(2026, 9, 1), 1_000, "a", account: "Cash", id: id),
            row(3, day(2026, 9, 2), 2_000, "b", account: "Cash", id: id),
        ])
        let plan = ImportPlan.make(file: file, existing: [], wallets: [cash], defaultWallet: nil)
        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.duplicates, 1)
    }

    // MARK: Wallets

    func testWalletsAreMatchedByNameAndUnknownOnesAreListedOnce() {
        let file = duit([
            row(2, day(2026, 9, 1), 1_000, "a", account: " bank "),
            row(3, day(2026, 9, 2), 2_000, "b", account: "GoPay"),
            row(4, day(2026, 9, 3), 3_000, "c", account: "gopay"),
            row(5, day(2026, 9, 4), 4_000, "d", type: .transfer, account: "Bank", to: "Dana"),
        ])
        let plan = ImportPlan.make(file: file, existing: [], wallets: [bank, cash], defaultWallet: nil)
        XCTAssertEqual(plan.items.map(\.accountName), ["Bank", "GoPay", "GoPay", "Bank"])
        XCTAssertEqual(plan.items[3].toAccountName, "Dana")
        XCTAssertEqual(plan.newWallets, ["GoPay", "Dana"])
    }

    func testRowsWithoutAWalletGoToTheChosenOneOrAreReported() {
        let file = statement([row(2, day(2025, 10, 1), 1_000, "x")])
        let chosen = ImportPlan.make(file: file, existing: [], wallets: [bank, cash], defaultWallet: "Cash")
        XCTAssertEqual(chosen.items.map(\.accountName), ["Cash"])
        XCTAssertTrue(chosen.newWallets.isEmpty)

        let none = ImportPlan.make(file: file, existing: [], wallets: [bank, cash], defaultWallet: nil)
        XCTAssertTrue(none.items.isEmpty)
        XCTAssertEqual(none.problems.map(\.row), [2])
    }

    func testAWalletGuessFollowsItsName() {
        XCTAssertEqual(WalletGuess.kind(for: "GoPay"), .ewallet)
        XCTAssertEqual(WalletGuess.kind(for: "ShopeePay"), .ewallet)
        XCTAssertEqual(WalletGuess.kind(for: "Dompet"), .cash)
        XCTAssertEqual(WalletGuess.kind(for: "Visa"), .credit)
        XCTAssertEqual(WalletGuess.kind(for: "Tabungan Emas"), .savings)
        XCTAssertEqual(WalletGuess.kind(for: "BCA"), .bank)
        XCTAssertEqual(WalletGuess.kind(for: "Danamon"), .bank) // not "Dana"
        XCTAssertEqual(WalletGuess.kind(for: "E-wallet"), .ewallet)
    }

    // MARK: Direction

    func testFlippingOnlyAppliesWhenTheDirectionWasAGuess() {
        let rows = [row(2, day(2025, 10, 1), 1_000, "x", type: .income)]
        let guessed = ImportPlan.make(file: statement(rows, guessed: true), existing: [], wallets: [bank],
                                      defaultWallet: "Bank", positiveIsIncome: false)
        XCTAssertEqual(guessed.items.map(\.row.type), [.expense])

        let sure = ImportPlan.make(file: statement(rows, guessed: false), existing: [], wallets: [bank],
                                   defaultWallet: "Bank", positiveIsIncome: false)
        XCTAssertEqual(sure.items.map(\.row.type), [.income])
    }

    func testTotals() {
        let file = statement([
            row(2, day(2025, 10, 1), 1_000, "a", type: .expense),
            row(3, day(2025, 10, 2), 2_000, "b", type: .expense),
            row(4, day(2025, 10, 3), 5_000, "c", type: .income),
        ])
        let plan = ImportPlan.make(file: file, existing: [], wallets: [bank], defaultWallet: "Bank")
        XCTAssertEqual(plan.expenseTotal, 3_000)
        XCTAssertEqual(plan.incomeTotal, 5_000)
    }

    // MARK: Categories

    func testCategoriesAreLearnedFromTitlesYouAlreadyUsed() {
        let history = [
            TestData.expense(32_000, on: day(2025, 9, 1), title: "Kopi Kenangan", category: "Coffee & Snacks"),
            TestData.expense(15_000, on: day(2025, 9, 2), title: "Es", category: "Food & Drinks"), // too short to match inside text
            Entry(type: .income, amount: 5_000_000, date: day(2025, 9, 3), title: "Gaji", categoryName: "Salary"),
        ]
        let file = statement([
            row(2, day(2025, 10, 1), 32_000, "KOPI KENANGAN"),
            row(3, day(2025, 10, 2), 30_000, "QRIS KOPI KENANGAN SCBD"),
            row(4, day(2025, 10, 3), 9_000, "ES TEH"),
            row(5, day(2025, 10, 4), 5_000_000, "TRSF GAJI SEP", type: .income),
            row(6, day(2025, 10, 5), 7_000, "GAJI KURIR"),       // an expense; "Gaji" is income history
            row(7, day(2025, 10, 6), 8_000, "WARTEG"),
        ])
        let plan = ImportPlan.make(file: file, existing: history, wallets: [bank], defaultWallet: "Bank")
        XCTAssertEqual(plan.items.map(\.categoryName), ["Coffee & Snacks", "Coffee & Snacks", nil, "Salary", nil, nil])
    }

    func testACategoryNamedInADuitExportIsKept() {
        let file = duit([row(2, day(2026, 9, 1), 1_000, "x", account: "Cash", category: "Health")])
        let history = [TestData.expense(1_000, on: day(2026, 8, 1), title: "x", category: "Other")]
        let plan = ImportPlan.make(file: file, existing: history, wallets: [cash], defaultWallet: nil)
        XCTAssertEqual(plan.items.map(\.categoryName), ["Health"])
    }
}
