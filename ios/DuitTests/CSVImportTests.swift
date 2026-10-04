import XCTest
@testable import Duit

/// The bank-statement layouts below are typical shapes (separate Debit and
/// Credit columns, one signed amount, an amount with a DB/CR mark, a type
/// column, Indonesian headers with `;`), written for these tests; none is a
/// real bank's file.
final class CSVImportTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }
    private func read(_ text: String) throws -> ImportFile { try CSVImport.read(text).get() }

    // MARK: Duit's own export

    func testReadsDuitsOwnExportBackExactly() throws {
        let lunch = Entry(
            type: .expense, amount: 50_000, date: day(2026, 9, 1), title: "Lunch, with \"friends\"",
            categoryName: "Food & Drinks", accountName: "Cash", rating: .regret
        )
        let salary = Entry(type: .income, amount: 16_500_000, date: day(2026, 9, 2), title: "Gaji", categoryName: "Salary", accountName: "Bank")
        let topUp = Entry(type: .transfer, amount: 200_000, date: day(2026, 9, 3), title: "Top up", accountName: "Bank", toAccountName: "GoPay")

        let file = try read(CSVExport.csv([lunch, salary, topUp]))

        XCTAssertEqual(file.kind, .duit)
        XCTAssertTrue(file.problems.isEmpty)
        XCTAssertFalse(file.directionIsGuessed)
        // The export is newest first; the header is row 1.
        XCTAssertEqual(file.rows, [
            ImportRow(row: 2, date: day(2026, 9, 3), type: .transfer, amount: 200_000, title: "Top up", categoryName: nil,
                      accountName: "Bank", toAccountName: "GoPay", rating: nil, id: topUp.id),
            ImportRow(row: 3, date: day(2026, 9, 2), type: .income, amount: 16_500_000, title: "Gaji", categoryName: "Salary",
                      accountName: "Bank", toAccountName: nil, rating: nil, id: salary.id),
            ImportRow(row: 4, date: day(2026, 9, 1), type: .expense, amount: 50_000, title: "Lunch, with \"friends\"", categoryName: "Food & Drinks",
                      accountName: "Cash", toAccountName: nil, rating: .regret, id: lunch.id),
        ])
    }

    func testAnOlderExportWithoutIDAndWorthItStillImports() throws {
        let text = """
        Date,Type,Amount,Signed amount,Category,Account,To account,Note
        2026-09-01,expense,50000,-50000,Food & Drinks,Cash,,Lunch
        """
        let file = try read(text)
        XCTAssertEqual(file.kind, .duit)
        XCTAssertEqual(file.rows.count, 1)
        XCTAssertNil(file.rows[0].id)
        XCTAssertNil(file.rows[0].rating)
        XCTAssertEqual(file.rows[0].title, "Lunch")
    }

    func testDuitRowsThatCantBeReadAreReportedNotGuessed() throws {
        let text = """
        Date,Type,Amount,Signed amount,Category,Account,To account,Note
        not a date,expense,100,-100,,Cash,,x
        2026-09-01,gift,100,0,,Cash,,x
        2026-09-01,expense,0,0,,Cash,,x
        2026-09-01,transfer,100,0,,Cash,,x
        2026-09-02,expense,100,-100,,Cash,,ok
        """
        let file = try read(text)
        XCTAssertEqual(file.rows.map(\.title), ["ok"])
        XCTAssertEqual(file.problems.map(\.row), [2, 3, 4, 5])
    }

    // MARK: Bank statements

    func testSeparateDebitAndCreditColumns() throws {
        let text = """
        Date,Description,Debit,Credit,Balance
        2025-10-01,KOPI KENANGAN,32000,,968000
        2025-10-02,GAJI,,5000000,5968000
        """
        let file = try read(text)
        XCTAssertEqual(file.kind, .statement)
        XCTAssertFalse(file.directionIsGuessed)
        XCTAssertEqual(file.rows.map(\.type), [.expense, .income])
        XCTAssertEqual(file.rows.map(\.amount), [32_000, 5_000_000])
        XCTAssertEqual(file.rows.map(\.title), ["KOPI KENANGAN", "GAJI"])
        XCTAssertEqual(file.rows.map(\.date), [day(2025, 10, 1), day(2025, 10, 2)])
        XCTAssertTrue(file.rows.allSatisfy { $0.accountName == nil && $0.categoryName == nil && $0.id == nil })
    }

    func testIndonesianSemicolonStatementWithLinesAboveTheTable() throws {
        let text = """
        Rekening;1234567890
        Periode;01/10/2025 - 31/10/2025

        Tanggal;Keterangan;Debet;Kredit;Saldo
        01/10/2025;QRIS   KOPI  KENANGAN;32.000,00;;968.000,00
        15/10/2025;TRSF GAJI;;5.000.000,00;5.968.000,00
        Saldo Akhir;;;;5.968.000,00
        """
        let file = try read(text)
        XCTAssertEqual(file.kind, .statement)
        XCTAssertEqual(file.rows.count, 2)
        XCTAssertEqual(file.rows[0].title, "QRIS KOPI KENANGAN") // padding collapsed
        XCTAssertEqual(file.rows[0].amount, 32_000)
        XCTAssertEqual(file.rows[0].type, .expense)
        XCTAssertEqual(file.rows[1].date, day(2025, 10, 15))
        XCTAssertEqual(file.rows[1].type, .income)
        XCTAssertTrue(file.problems.isEmpty, "the closing balance line is skipped quietly")
    }

    func testOneSignedAmountColumn() throws {
        let file = try read("Date,Details,Amount\n2025-10-01,Coffee,-32000\n2025-10-02,Salary,5000000\n")
        XCTAssertEqual(file.rows.map(\.type), [.expense, .income])
        XCTAssertEqual(file.rows.map(\.amount), [32_000, 5_000_000])
        XCTAssertFalse(file.directionIsGuessed)
    }

    func testAnAmountCarryingADebitOrCreditMark() throws {
        let text = """
        Tanggal,Keterangan,Cabang,Jumlah,Saldo
        '01/10/2025,"KARTU DEBIT 1234",0998,"150000.00 DB","850000.00"
        '02/10/2025,"TRSF GAJI",0998,"5000000.00 CR","5850000.00"
        """
        let file = try read(text)
        XCTAssertEqual(file.rows.map(\.type), [.expense, .income])
        XCTAssertEqual(file.rows.map(\.amount), [150_000, 5_000_000])
        XCTAssertEqual(file.rows.map(\.date), [day(2025, 10, 1), day(2025, 10, 2)])
        XCTAssertEqual(file.rows[0].title, "KARTU DEBIT 1234")
    }

    func testATypeColumnSaysWhichWayTheMoneyWent() throws {
        let file = try read("Date,Description,Type,Amount\n2025-10-01,Coffee,DB,32000\n2025-10-02,Salary,CR,5000000\n")
        XCTAssertEqual(file.rows.map(\.type), [.expense, .income])
        XCTAssertFalse(file.directionIsGuessed)
    }

    func testPlainPositiveAmountsAreAGuessTheUserCanFlip() throws {
        let file = try read("Date,Description,Amount\n2025-10-01,Coffee,32000\n2025-10-02,Lunch,20000\n")
        XCTAssertTrue(file.directionIsGuessed)
        XCTAssertEqual(file.rows.map(\.type), [.income, .income])
    }

    func testMonthFirstDatesAreRecognisedFromTheFileItself() throws {
        let file = try read("Date,Description,Amount\n10/31/2025,x,-100\n10/01/2025,y,-200\n")
        XCTAssertEqual(file.rows.map(\.date), [day(2025, 10, 31), day(2025, 10, 1)])
    }

    func testUnreadableRowsAreReportedAndTheRestStillImport() throws {
        let text = """
        Date,Description,Debit,Credit
        2025-10-01,ok,1000,
        soon,bad date,2000,
        2025-10-03,both,100,200
        2025-10-04,junk,abc,
        """
        let file = try read(text)
        XCTAssertEqual(file.rows.map(\.title), ["ok"])
        XCTAssertEqual(file.problems.map(\.row), [3, 4, 5])
        XCTAssertEqual(file.problems[0].reason, "date not recognised: soon")
    }

    func testHeadersInEnglishAndIndonesianAreFound() {
        let samples: [(header: String, row: String)] = [
            ("Date,Description,Debit,Credit", "2025-10-01,Coffee,1000,"),
            ("Tanggal,Keterangan,Debet,Kredit", "2025-10-01,Coffee,1000,"),
            ("Transaction Date,Narration,Withdrawal,Deposit", "2025-10-01,Coffee,1000,"),
            ("Tgl,Uraian,Keluar,Masuk", "2025-10-01,Coffee,1000,"),
            ("Tanggal Transaksi,Deskripsi,Jumlah", "2025-10-01,Coffee,-1000"),
            ("Posting Date,Details,Amount,Balance", "2025-10-01,Coffee,-1000,5000"),
        ]
        for sample in samples {
            let file = try? CSVImport.read(sample.header + "\n" + sample.row + "\n").get()
            XCTAssertEqual(file?.rows.count, 1, sample.header)
            XCTAssertEqual(file?.rows.first?.amount, 1_000, sample.header)
            XCTAssertEqual(file?.rows.first?.type, .expense, sample.header)
        }
    }

    // MARK: Files that can't be imported

    func testNothingToReadIsSaidPlainly() {
        XCTAssertEqual(CSVImport.read("").failureValue, .empty)
        XCTAssertEqual(CSVImport.read("Name,Colour\nA,red").failureValue, .noColumns)
        XCTAssertEqual(CSVImport.read("Date,Description,Debit,Credit\n").failureValue, .noTransactions)
        XCTAssertFalse(ImportFailure.noColumns.message.isEmpty)
    }

    func testHeadersAreComparedWithoutCaseAccentsOrPunctuation() {
        XCTAssertEqual(CSVImport.normalise("  Tanggal   Transaksi "), "tanggal transaksi")
        XCTAssertEqual(CSVImport.normalise("Débit (IDR)"), "debit idr")
        XCTAssertEqual(CSVImport.tidy("A   B\t C"), "A B C")
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
