import XCTest
@testable import Duit

final class BalanceCheckTests: XCTestCase {
    private typealias Candidate = BalanceCheck.Candidate
    private let wallet = UUID()
    private let other = UUID()

    private func c(_ title: String, _ amount: Int) -> Candidate {
        Candidate(title: title, amount: amount, categoryName: nil, count: 1)
    }

    func testFindsTheSmallestExactCombination() {
        let list = [c("Kopi", 20_000), c("GrabFood", 27_000), c("Gojek", 15_000)]
        XCTAssertEqual(BalanceCheck.bestCombo(list, gap: 47_000)?.map(\.title), ["Kopi", "GrabFood"])
        XCTAssertEqual(BalanceCheck.bestCombo(list, gap: 15_000)?.map(\.title), ["Gojek"])
        XCTAssertEqual(BalanceCheck.bestCombo(list, gap: 62_000)?.count, 3)
    }

    func testPrefersFewerItems() {
        let list = [c("A", 10_000), c("B", 10_000), c("C", 20_000)]
        XCTAssertEqual(BalanceCheck.bestCombo(list, gap: 20_000)?.map(\.title), ["C"]) // not A + B
    }

    func testNoComboWhenNothingAddsUp() {
        XCTAssertNil(BalanceCheck.bestCombo([c("A", 10_000)], gap: 1))
        XCTAssertNil(BalanceCheck.bestCombo([], gap: 10_000))
        XCTAssertNil(BalanceCheck.bestCombo([c("A", 10_000)], gap: 0))
    }

    func testOutcomeForAnAccountYouHold() {
        XCTAssertEqual(BalanceCheck.outcome(isCard: false, duitSays: 1_000_000, appSays: 0), .waiting)
        XCTAssertEqual(BalanceCheck.outcome(isCard: false, duitSays: 1_000_000, appSays: 1_000_000), .balanced)
        XCTAssertEqual(BalanceCheck.outcome(isCard: false, duitSays: 1_000_000, appSays: 953_000), .missing(47_000))
        XCTAssertEqual(BalanceCheck.outcome(isCard: false, duitSays: 1_000_000, appSays: 1_050_000), .extra(50_000))
    }

    func testOutcomeForACardIsWhatYouOwe() {
        // Owing more than Duit knew means spending went unlogged.
        XCTAssertEqual(BalanceCheck.outcome(isCard: true, duitSays: 4_850_000, appSays: 5_036_000), .missing(186_000))
        XCTAssertEqual(BalanceCheck.outcome(isCard: true, duitSays: 4_850_000, appSays: 4_800_000), .extra(50_000))
    }

    func testCandidatesComeFromTheAccountsOwnHistoryAtTheLatestPrice() {
        let day = TestData.day(2026, 9, 20)
        let newestFirst = [
            TestData.expense(32_000, on: day, title: "Kopi Kenangan", category: "Coffee & Snacks", account: wallet),
            TestData.expense(15_000, on: day, title: "Gojek", category: "Transport", account: wallet),
            TestData.expense(30_000, on: day, title: "Kopi Kenangan", category: "Coffee & Snacks", account: wallet), // older, cheaper
            TestData.expense(99_000, on: day, title: "Elsewhere", account: other), // another account
            TestData.income(500_000, on: day, account: wallet), // not spending
        ]
        let list = BalanceCheck.candidates(accountID: wallet, kind: .ewallet, entries: newestFirst)
        XCTAssertEqual(list.map(\.title), ["Kopi Kenangan", "Gojek", "Admin fee"])
        XCTAssertEqual(list[0].amount, 32_000)
        XCTAssertEqual(list[0].count, 2)
        XCTAssertEqual(list[2].count, 0) // a common hidden cost, never logged
    }

    func testCandidatesAreCappedAtSixAndSkipDuplicateExtras() {
        let day = TestData.day(2026, 9, 20)
        // "Admin fee" is already in the history (newest), so it must not be added a second time.
        var list: [Entry] = [TestData.expense(1_000, on: day, title: "Admin fee", account: wallet)]
        list += (1...8).map { TestData.expense($0 * 1_000, on: day, title: "Item \($0)", account: wallet) }
        let result = BalanceCheck.candidates(accountID: wallet, kind: .ewallet, entries: list)
        XCTAssertEqual(result.count, 6)
        XCTAssertEqual(result.filter { $0.title == "Admin fee" }.count, 1)
        XCTAssertEqual(result.first?.title, "Admin fee")
    }

    func testEachKindOfAccountHasItsOwnHiddenCosts() {
        XCTAssertEqual(BalanceCheck.commonExtras(for: .cash).map(\.title), ["Parkir", "Amal Jumat"])
        XCTAssertEqual(BalanceCheck.commonExtras(for: .credit).map(\.title), ["Iuran kartu"])
        XCTAssertTrue(BalanceCheck.commonExtras(for: .savings).isEmpty)
    }
}
