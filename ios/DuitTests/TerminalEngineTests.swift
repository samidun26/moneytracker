import XCTest
@testable import Duit

/// The Terminal's question side. Numbers come from the prototype's sample
/// month: Rp 11.521.500 spent, Rp 317.000 of it on Coffee & Snacks.
final class TerminalEngineTests: XCTestCase {
    private let context = TerminalContext(
        monthName: "September",
        totalSpent: 11_521_500,
        spentByCategory: ["Coffee & Snacks": 317_000, "Transport": 1_000_000],
        categoryNames: ["Food & Drinks", "Coffee & Snacks", "Transport"],
        expenses: [
            (title: "Gojek", amount: 15_000),
            (title: "GrabCar", amount: 38_000),
            (title: "GrabFood", amount: 52_000),
            (title: "Kos Tebet", amount: 3_500_000),
            (title: "Superindo", amount: 412_500),
        ],
        allowanceLines: ["Rp 68.357 a day for 7 days (battery 4%).", "Payday: Thu 1 Oct."],
        inflationLines: ["Your basket: +22% in 12 months."]
    )

    func testWhatCountsAsAQuestion() {
        for q in ["sisa?", "sisa", "grab vs gojek", "help", "berapa kopi", "terbesar", "?", "inflasi", "total"] {
            XCTAssertTrue(TerminalEngine.isQuestion(q), q)
        }
        for entry in ["mie ayam 22rb", "es teh goceng", "gaji 16,5jt", "topup gopay 100rb"] {
            XCTAssertFalse(TerminalEngine.isQuestion(entry), entry)
        }
    }

    func testHelp() {
        let lines = TerminalEngine.answer("help", context: context)
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[0].hasPrefix("LOG"))
        XCTAssertTrue(lines[2].hasPrefix("ASK"))
    }

    func testAllowanceAndInflationAreFedFromTheContext() {
        XCTAssertEqual(TerminalEngine.answer("sisa?", context: context), context.allowanceLines)
        XCTAssertEqual(TerminalEngine.answer("uang harian", context: context), context.allowanceLines)
        XCTAssertEqual(TerminalEngine.answer("inflasi", context: context), context.inflationLines)
    }

    func testBiggestExpenses() {
        let lines = TerminalEngine.answer("terbesar", context: context)
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasPrefix("1. Kos Tebet"))
        XCTAssertTrue(lines[0].hasSuffix("Rp 3.500.000"))
        XCTAssertTrue(lines[1].hasPrefix("2. Superindo"))
    }

    func testComparisonDrawsBars() {
        let lines = TerminalEngine.answer("grab vs gojek", context: context)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("Grab (2x)"))
        XCTAssertTrue(lines[1].hasPrefix("Gojek (1x)"))
        XCTAssertTrue(lines[0].contains(String(repeating: "#", count: 14))) // the bigger one gets the full bar
        XCTAssertTrue(lines[0].hasSuffix("Rp 90 rb"))
        XCTAssertEqual(lines[1].filter { $0 == "#" }.count, 2)
    }

    func testCategoryTotalWithShareOfSpending() {
        let lines = TerminalEngine.answer("berapa kopi?", context: context)
        XCTAssertEqual(lines, ["Coffee & Snacks in September: Rp 317.000 (2,8% of spending)"])
    }

    func testTotalAndNothingFound() {
        XCTAssertEqual(TerminalEngine.answer("berapa?", context: context), ["September so far: Rp 11.521.500 spent."])
        XCTAssertEqual(TerminalEngine.answer("berapa sushi?", context: context), ["Nothing found for \"sushi\" this month."])
    }

    func testPaddingAndBars() {
        XCTAssertEqual(TerminalEngine.pad("abc", 6), "abc   ")
        XCTAssertEqual(TerminalEngine.pad("abcdefgh", 6), "abcde~")
        XCTAssertEqual(TerminalEngine.bars(50, max: 100), String(repeating: "#", count: 7))
        XCTAssertEqual(TerminalEngine.bars(1, max: 1000), "#") // never an empty bar for a real amount
        XCTAssertEqual(TerminalEngine.bars(5, max: 0), "")
    }
}
