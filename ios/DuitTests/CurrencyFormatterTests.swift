import XCTest
@testable import Duit

/// Ported from src/lib/money.test.ts — same cases, same expected strings.
final class CurrencyFormatterTests: XCTestCase {
    func testFormatsIDRWithDotThousandsSeparatorsAndNoDecimals() {
        XCTAssertEqual(CurrencyFormatter.formatRp(150_000), "Rp 150.000")
        XCTAssertEqual(CurrencyFormatter.formatRp(8_500_000), "Rp 8.500.000")
        XCTAssertEqual(CurrencyFormatter.formatRp(-45_000), "\u{2212}Rp 45.000")
        XCTAssertEqual(CurrencyFormatter.formatRp(0), "Rp 0")
    }

    func testUsesIndonesianCompactUnits() {
        XCTAssertEqual(CurrencyFormatter.formatCompact(150_000), "150 rb")
        XCTAssertEqual(CurrencyFormatter.formatCompact(1_250_000), "1,3 jt")
        XCTAssertEqual(CurrencyFormatter.formatCompact(2_000_000_000), "2 M")
    }

    func testSignsFlows() {
        XCTAssertEqual(CurrencyFormatter.formatSigned(8_500_000), "+8.500.000")
        XCTAssertEqual(CurrencyFormatter.formatSigned(-45_000), "\u{2212}45.000")
    }

    func testParsesUserInput() {
        XCTAssertEqual(CurrencyFormatter.parseAmount("Rp 12.500"), 12_500)
        XCTAssertEqual(CurrencyFormatter.parseAmount(""), 0)
        XCTAssertEqual(CurrencyFormatter.parseAmount("99999999999999"), 999_999_999_999)
        XCTAssertEqual(CurrencyFormatter.parseSignedAmount("-1.500.000"), -1_500_000)
        XCTAssertEqual(CurrencyFormatter.parseSignedAmount("\u{2212}2.000"), -2_000)
    }
}
