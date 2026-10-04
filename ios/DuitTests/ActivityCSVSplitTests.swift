import XCTest
@testable import Duit

final class ActivityCSVSplitTests: XCTestCase {
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date { TestData.day(y, m, d) }

    // MARK: Activity search

    private var sample: [Entry] {
        [
            TestData.expense(32_000, on: day(2026, 9, 24), title: "Kopi Kenangan", category: "Coffee & Snacks", accountName: "GoPay"),
            TestData.expense(27_000, on: day(2026, 9, 24), title: "Nasi Uduk", category: "Food & Drinks", accountName: "Cash"),
            TestData.income(3_200_000, on: day(2026, 9, 18), title: "Logo design", category: "Freelance"),
            Entry(type: .transfer, amount: 600_000, date: day(2026, 9, 22), title: "Top up GoPay", accountName: "Bank", toAccountName: "GoPay"),
        ]
    }

    func testFiltersByDirection() {
        XCTAssertEqual(sample.filter { ActivitySearch.matches($0, filter: .out, query: "") }.count, 2)
        XCTAssertEqual(sample.filter { ActivitySearch.matches($0, filter: .income, query: "") }.count, 1)
        XCTAssertEqual(sample.filter { ActivitySearch.matches($0, filter: .all, query: "") }.count, 4)
    }

    func testSearchesNamesCategoriesAndAccounts() {
        func hits(_ q: String) -> [String] {
            sample.filter { ActivitySearch.matches($0, filter: .all, query: q) }.map(\.displayName)
        }
        XCTAssertEqual(hits("kopi"), ["Kopi Kenangan"])
        XCTAssertEqual(hits("FREELANCE"), ["Logo design"])
        XCTAssertEqual(hits("cash"), ["Nasi Uduk"])
        XCTAssertEqual(hits("gopay").count, 2) // the wallet itself and the top-up into it
    }

    func testSearchesAmountsWithOrWithoutDots() {
        func hits(_ q: String) -> Int { sample.filter { ActivitySearch.matches($0, filter: .all, query: q) }.count }
        XCTAssertEqual(hits("27000"), 1)
        XCTAssertEqual(hits("27.000"), 1)
        XCTAssertEqual(hits("32000"), 2) // 32.000 and also 3.200.000 contain those digits
        XCTAssertEqual(hits("999"), 0)
    }

    func testGroupsByDayWithTheNet() {
        let groups = ActivitySearch.groups(ActivitySearch.newestFirst(sample))
        XCTAssertEqual(groups.map(\.date), [day(2026, 9, 24), day(2026, 9, 22), day(2026, 9, 18)])
        XCTAssertEqual(groups[0].items.count, 2)
        XCTAssertEqual(groups[0].net, -59_000)
        XCTAssertEqual(groups[1].net, 0) // a transfer is neither in nor out
        XCTAssertEqual(groups[2].net, 3_200_000)
    }

    func testNewestFirstBreaksTiesByWhenItWasLogged() {
        let early = TestData.expense(1, on: day(2026, 9, 1), title: "early", created: Date(timeIntervalSince1970: 100))
        let late = TestData.expense(2, on: day(2026, 9, 1), title: "late", created: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(ActivitySearch.newestFirst([early, late]).map(\.title), ["late", "early"])
    }

    func testDisplayNameFallsBackToCategory() {
        XCTAssertEqual(TestData.expense(1, on: day(2026, 9, 1), category: "Health").displayName, "Health")
        XCTAssertEqual(TestData.expense(1, on: day(2026, 9, 1)).displayName, "Uncategorized")
        XCTAssertEqual(TestData.transfer(1, from: UUID(), to: UUID(), on: day(2026, 9, 1)).displayName, "Transfer")
    }

    // MARK: CSV

    func testCSVHasTheWebAppsColumnsNewestFirstThenIDAndWorthIt() {
        let list = [
            TestData.expense(50_000, on: day(2026, 9, 1), title: "Lunch", category: "Food & Drinks", accountName: "Cash"),
            TestData.income(1_000_000, on: day(2026, 9, 2), title: "Gaji", category: "Salary", account: nil),
            Entry(type: .transfer, amount: 200_000, date: day(2026, 9, 3), accountName: "Bank", toAccountName: "GoPay"),
        ]
        let lines = CSVExport.csv(list).components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "Date,Type,Amount,Signed amount,Category,Account,To account,Note,ID,Worth it")
        XCTAssertEqual(lines[1], "2026-09-03,transfer,200000,0,,Bank,GoPay,,\(list[2].id.uuidString),")
        XCTAssertEqual(lines[2], "2026-09-02,income,1000000,1000000,Salary,,,Gaji,\(list[1].id.uuidString),")
        XCTAssertEqual(lines[3], "2026-09-01,expense,50000,-50000,Food & Drinks,Cash,,Lunch,\(list[0].id.uuidString),")
        XCTAssertEqual(lines.count, 4)
    }

    func testCSVKeepsTheWorthItAnswer() {
        let worth = TestData.expense(850_000, on: day(2026, 9, 2), title: "Keyboard", rating: .worth)
        let regret = TestData.expense(499_000, on: day(2026, 9, 1), title: "Jacket", rating: .regret)
        let lines = CSVExport.csv([worth, regret]).components(separatedBy: "\n")
        XCTAssertTrue(lines[1].hasSuffix(",\(worth.id.uuidString),worth"))
        XCTAssertTrue(lines[2].hasSuffix(",\(regret.id.uuidString),regret"))
    }

    func testCSVQuotesCommasQuotesAndNewlines() {
        XCTAssertEqual(CSVExport.cell("plain"), "plain")
        XCTAssertEqual(CSVExport.cell("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExport.cell("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExport.cell("two\nlines"), "\"two\nlines\"")
    }

    func testEmptyExportIsJustTheHeader() {
        XCTAssertEqual(CSVExport.csv([]), "Date,Type,Amount,Signed amount,Category,Account,To account,Note,ID,Worth it")
    }

    // MARK: Payday split

    func testSpendingMoneyIsWhatIsLeftAfterEveryJob() {
        // The prototype: Rp 16,5 jt salary, Rp 8,75 jt given jobs.
        let left = PaydaySplit.spendingMoney(salary: 16_500_000, buckets: [3_500_000, 3_000_000, 1_000_000, 1_250_000])
        XCTAssertEqual(left, 7_750_000)
        XCTAssertEqual(PaydaySplit.perDay(spending: left, daysUntilNextPayday: 31), 250_000)
    }

    func testOverAllocatingGoesNegativeAndHasNoDailyAllowance() {
        let left = PaydaySplit.spendingMoney(salary: 1_000_000, buckets: [800_000, 500_000])
        XCTAssertEqual(left, -300_000)
        XCTAssertEqual(PaydaySplit.perDay(spending: left, daysUntilNextPayday: 30), 0)
        XCTAssertEqual(PaydaySplit.perDay(spending: 100, daysUntilNextPayday: 0), 100) // never divides by zero
    }

    func testBucketsStepByQuarterMillionAndNeverGoBelowZero() {
        XCTAssertEqual(PaydaySplit.stepped(1_000_000, by: PaydaySplit.step), 1_250_000)
        XCTAssertEqual(PaydaySplit.stepped(100_000, by: -PaydaySplit.step), 0)
    }
}
