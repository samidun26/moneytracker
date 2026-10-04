import XCTest
@testable import Duit

/// The Duit Terminal's slang parser, against the examples the prototype
/// itself advertises ("mie ayam goceng", "bensin ceban kemarin", "dua puluh
/// lima ribu", "kos 3,5jt bca", "topup gopay 100rb", "gaji 16,5jt").
final class SlangParserTests: XCTestCase {
    private let cash = AccountRef(name: "Cash", kind: .cash)
    private let bca = AccountRef(name: "BCA", kind: .bank)
    private let gopay = AccountRef(name: "GoPay", kind: .ewallet)
    private let visa = AccountRef(name: "Visa", kind: .credit)

    private func parse(_ text: String, history: [Entry] = []) -> ParsedEntry {
        let context = ParseContext(
            accounts: [cash, bca, gopay, visa],
            history: history,
            defaultExpenseAccountID: gopay.id,
            defaultIncomeAccountID: bca.id
        )
        return SlangParser.parse(text, context: context)
    }

    func testPlainAmountWithSuffix() {
        let p = parse("mie ayam 22rb")
        XCTAssertTrue(p.ok)
        XCTAssertEqual(p.amount, 22_000)
        XCTAssertEqual(p.title, "Mie Ayam")
        XCTAssertEqual(p.categoryName, "Food & Drinks")
        XCTAssertEqual(p.type, .expense)
        XCTAssertEqual(p.dayOffset, 0)
        XCTAssertEqual(p.accountID, gopay.id) // the default for expenses
    }

    func testSlangMoneyWords() {
        let p = parse("es teh goceng")
        XCTAssertEqual(p.amount, 5_000)
        XCTAssertEqual(p.title, "Es Teh")
        XCTAssertEqual(p.categoryName, "Coffee & Snacks")
        XCTAssertEqual(p.notes, ["goceng = Rp 5.000"])
    }

    func testSmallSlangIsReadAsThousands() {
        let p = parse("gopek")
        XCTAssertEqual(p.amount, 500_000)
        XCTAssertEqual(p.notes, ["gopek read as Rp 500.000"])
    }

    func testYesterday() {
        let p = parse("bensin ceban kemarin")
        XCTAssertEqual(p.amount, 10_000)
        XCTAssertEqual(p.dayOffset, -1)
        XCTAssertEqual(p.title, "Bensin")
        XCTAssertEqual(p.categoryName, "Transport")
        XCTAssertEqual(parse("mie ayam 20rb hari ini").dayOffset, 0)
    }

    func testAmountsWrittenAsWords() {
        XCTAssertEqual(parse("dua puluh lima ribu").amount, 25_000)
        XCTAssertEqual(parse("dua ratus lima puluh ribu").amount, 250_000)
        XCTAssertEqual(parse("seratus ribu").amount, 100_000)
        XCTAssertEqual(parse("dua belas ribu").amount, 12_000)
        XCTAssertEqual(parse("sejuta").amount, 1_000_000)
    }

    func testAnAmountOnlyEntryIsTitledAfterItsCategory() {
        let p = parse("dua puluh lima ribu")
        XCTAssertEqual(p.title, "Other")
        XCTAssertEqual(p.categoryName, "Other")
    }

    func testThousandsSeparatorsAndDecimals() {
        XCTAssertEqual(parse("nasi uduk 25.000").amount, 25_000)
        XCTAssertEqual(parse("kos 3,5jt").amount, 3_500_000)
        XCTAssertEqual(parse("gaji 16,5jt").amount, 16_500_000)
        XCTAssertEqual(parse("kopi 18k").amount, 18_000)
        XCTAssertEqual(parse("bakso rp 15.000").amount, 15_000)
        XCTAssertEqual(parse("kopi 1.500.000").amount, 1_500_000)
    }

    func testSuffixAsASeparateWord() {
        let p = parse("es teh 5 ribu")
        XCTAssertEqual(p.amount, 5_000)
        XCTAssertEqual(p.title, "Es Teh")
    }

    func testNamingAnAccount() {
        let p = parse("kos 3,5jt bca")
        XCTAssertEqual(p.amount, 3_500_000)
        XCTAssertEqual(p.title, "Kos")
        XCTAssertEqual(p.categoryName, "Housing")
        XCTAssertEqual(p.accountID, bca.id)
    }

    func testAccountKindWordsFindTheUsersWallet() {
        XCTAssertEqual(parse("kopi 18rb tunai").accountID, cash.id)
        XCTAssertEqual(parse("netflix 186rb cc").accountID, visa.id)
        XCTAssertEqual(parse("kopi 18rb ovo").accountID, gopay.id) // any e-wallet word → the user's e-wallet
    }

    func testIncome() {
        let p = parse("gaji 16,5jt")
        XCTAssertEqual(p.type, .income)
        XCTAssertEqual(p.categoryName, "Salary")
        XCTAssertEqual(p.title, "Gaji")
        XCTAssertEqual(p.accountID, bca.id) // the default for income
        XCTAssertEqual(parse("thr 2jt").categoryName, "Bonus & THR")
    }

    func testTopUpMovesMoneyFromTheBankToTheWallet() {
        let p = parse("topup gopay 100rb")
        XCTAssertTrue(p.ok)
        XCTAssertEqual(p.type, .transfer)
        XCTAssertEqual(p.amount, 100_000)
        XCTAssertEqual(p.fromAccountID, bca.id)
        XCTAssertEqual(p.toAccountID, gopay.id)
        XCTAssertEqual(p.title, "Top up GoPay")
        XCTAssertNil(p.categoryName)
        XCTAssertEqual(parse("top up gopay 50rb").amount, 50_000) // two words work too
    }

    func testTopUpWithoutTwoWalletsIsNotOk() {
        let context = ParseContext(accounts: [cash], history: [], defaultExpenseAccountID: cash.id, defaultIncomeAccountID: cash.id)
        let p = SlangParser.parse("topup 100rb", context: context)
        XCTAssertFalse(p.ok)
        XCTAssertFalse(p.notes.isEmpty)
    }

    func testNoAmountIsNotOk() {
        let p = parse("makan siang")
        XCTAssertFalse(p.ok)
        XCTAssertEqual(p.amount, 0)
        XCTAssertFalse(parse("").ok)
    }

    func testAPastTitleBringsItsCategoryAndAccount() {
        let past = Entry(
            type: .expense, amount: 15_000, date: TestData.day(2026, 9, 1), title: "Warteg",
            categoryName: "Food & Drinks", accountID: cash.id
        )
        let p = parse("warteg 15rb", history: [past])
        XCTAssertEqual(p.accountID, cash.id)
        XCTAssertEqual(p.categoryName, "Food & Drinks")
        XCTAssertTrue(p.notes.contains("Matched your past \"Warteg\""))
    }

    func testUnknownWordsFallBackToOther() {
        let p = parse("xyzzy 10rb")
        XCTAssertEqual(p.categoryName, "Other")
        XCTAssertEqual(p.title, "Xyzzy")
    }

    func testPendingWordsThatDoNotAddUpStayInTheTitle() {
        // "satu" alone is not an amount; it's part of the name.
        let p = parse("satu kopi 18rb")
        XCTAssertEqual(p.amount, 18_000)
        XCTAssertEqual(p.title, "Satu Kopi")
    }
}
