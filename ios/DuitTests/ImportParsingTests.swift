import XCTest
@testable import Duit

final class ImportParsingTests: XCTestCase {
    // MARK: Amounts

    private func amount(_ text: String) -> ImportAmount.Parsed? { ImportAmount.parse(text) }

    func testIndonesianAndEnglishNumberHabits() {
        XCTAssertEqual(amount("150.000")?.value, 150_000)
        XCTAssertEqual(amount("150,000")?.value, 150_000)
        XCTAssertEqual(amount("1.234")?.value, 1_234)
        XCTAssertEqual(amount("1.234.567,89")?.value, 1_234_568)
        XCTAssertEqual(amount("1,234,567.89")?.value, 1_234_568)
        XCTAssertEqual(amount("1500000.00")?.value, 1_500_000)
        XCTAssertEqual(amount("5,00")?.value, 5)
        XCTAssertEqual(amount("12.5")?.value, 13) // rounds to whole rupiah
        XCTAssertEqual(amount("32000")?.value, 32_000)
    }

    func testCurrencyLabelsAreIgnored() {
        XCTAssertEqual(amount("Rp 32.000"), ImportAmount.Parsed(value: 32_000, direction: nil))
        XCTAssertEqual(amount("IDR 1,500,000"), ImportAmount.Parsed(value: 1_500_000, direction: nil))
        XCTAssertEqual(amount("Rp. 2.500"), ImportAmount.Parsed(value: 2_500, direction: nil))
    }

    func testSignsBracketsAndDebitCreditMarkersGiveTheDirection() {
        XCTAssertEqual(amount("-32.000"), ImportAmount.Parsed(value: 32_000, direction: .moneyOut))
        XCTAssertEqual(amount("\u{2212}32.000"), ImportAmount.Parsed(value: 32_000, direction: .moneyOut))
        XCTAssertEqual(amount("32.000-"), ImportAmount.Parsed(value: 32_000, direction: .moneyOut))
        XCTAssertEqual(amount("(1.500)"), ImportAmount.Parsed(value: 1_500, direction: .moneyOut))
        XCTAssertEqual(amount("+100"), ImportAmount.Parsed(value: 100, direction: .moneyIn))
        XCTAssertEqual(amount("150000.00 DB"), ImportAmount.Parsed(value: 150_000, direction: .moneyOut))
        XCTAssertEqual(amount("150000.00DB"), ImportAmount.Parsed(value: 150_000, direction: .moneyOut))
        XCTAssertEqual(amount("5000000.00 CR"), ImportAmount.Parsed(value: 5_000_000, direction: .moneyIn))
        XCTAssertEqual(amount("2.500.000,00 D"), ImportAmount.Parsed(value: 2_500_000, direction: .moneyOut))
    }

    func testNonNumbersAreNotAmounts() {
        for text in ["", "   ", "abc", "-", "Rp", "."] {
            XCTAssertNil(amount(text), "\"\(text)\"")
        }
    }

    // MARK: Dates

    func testCommonDateFormats() {
        let oct1 = TestData.day(2025, 10, 1)
        let formats = [
            "2025-10-01", "2025/10/01", "01/10/2025", "01-10-2025", "01.10.2025", "1 Okt 2025", "1 Oktober 2025",
            "01-Oct-25", "01 Oct 2025", "Rabu, 1 Oktober 2025", "Wed, 1 Oct 2025", "2025-10-01 14:03:22",
            "2025-10-01T14:03:22Z", "01/10/2025 14:03", "'01/10/2025", "20251001", "Oct 1, 2025",
        ]
        for text in formats {
            XCTAssertEqual(ImportDate.parse(text), oct1, text)
        }
    }

    func testIndonesianMonthNames() {
        XCTAssertEqual(ImportDate.parse("17 Agu 2025"), TestData.day(2025, 8, 17))
        XCTAssertEqual(ImportDate.parse("17 Agustus 2025"), TestData.day(2025, 8, 17))
        XCTAssertEqual(ImportDate.parse("5 Mei 2025"), TestData.day(2025, 5, 5))
        XCTAssertEqual(ImportDate.parse("25 Des 2025"), TestData.day(2025, 12, 25))
    }

    func testDayFirstUnlessTheFileProvesOtherwise() {
        XCTAssertEqual(ImportDate.detectOrder(["01/02/2025"]), .dayFirst)
        XCTAssertEqual(ImportDate.detectOrder(["13/02/2025", "01/02/2025"]), .dayFirst)
        XCTAssertEqual(ImportDate.detectOrder(["01/02/2025", "02/13/2025"]), .monthFirst)
        XCTAssertEqual(ImportDate.parse("02/01/2025", order: .dayFirst), TestData.day(2025, 1, 2))
        XCTAssertEqual(ImportDate.parse("02/01/2025", order: .monthFirst), TestData.day(2025, 2, 1))
    }

    func testRejectsWhatIsNotACompleteDate() {
        // No year, a time instead of a year, impossible days and months.
        for text in ["", "garbage", "01/10", "01/10 14:30", "30/02/2025", "32/01/2025", "13/13/2025", "2025-13-01"] {
            XCTAssertNil(ImportDate.parse(text), "\"\(text)\"")
        }
    }
}
