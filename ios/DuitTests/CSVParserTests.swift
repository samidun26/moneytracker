import XCTest
@testable import Duit

final class CSVParserTests: XCTestCase {
    func testSplitsRowsAndCells() {
        XCTAssertEqual(CSVParser.parse("a,b,c\n1,2,3", delimiter: ","), [["a", "b", "c"], ["1", "2", "3"]])
        XCTAssertEqual(CSVParser.parse("a,,c", delimiter: ","), [["a", "", "c"]])
    }

    func testQuotedCellsKeepCommasQuotesAndLineBreaks() {
        let text = "Date,Note\n2026-09-01,\"Lunch, with \"\"friends\"\"\"\n2026-09-02,\"two\nlines\""
        XCTAssertEqual(CSVParser.parse(text, delimiter: ","), [
            ["Date", "Note"],
            ["2026-09-01", "Lunch, with \"friends\""],
            ["2026-09-02", "two\nlines"],
        ])
    }

    func testSpacesBeforeAQuoteStillOpenIt() {
        XCTAssertEqual(CSVParser.parse("a, \"x,y\"", delimiter: ","), [["a", "x,y"]])
    }

    func testWindowsAndOldMacLineEndsAndAMissingFinalNewline() {
        XCTAssertEqual(CSVParser.parse("a,b\r\n1,2\r\n", delimiter: ","), [["a", "b"], ["1", "2"]])
        XCTAssertEqual(CSVParser.parse("a,b\r1,2", delimiter: ","), [["a", "b"], ["1", "2"]])
        XCTAssertEqual(CSVParser.parse("a,b\n1,2", delimiter: ","), [["a", "b"], ["1", "2"]])
    }

    func testAByteOrderMarkAndBlankLinesAreDropped() {
        XCTAssertEqual(CSVParser.parse("\u{FEFF}a,b\n\n,\n1,2\n", delimiter: ","), [["a", "b"], ["1", "2"]])
        XCTAssertEqual(CSVParser.parse("", delimiter: ","), [])
    }

    func testDetectsTheSeparator() {
        XCTAssertEqual(CSVParser.detectDelimiter("Date,Amount\n2026-09-01,100"), ",")
        XCTAssertEqual(CSVParser.detectDelimiter("Date\tAmount\n2026-09-01\t100"), "\t")
        // Decimal commas must not win over the real separator.
        XCTAssertEqual(
            CSVParser.detectDelimiter("Tanggal;Keterangan;Jumlah\n01/09/2026;Kopi;1.500,00\n02/09/2026;Nasi;20.000,00"),
            ";"
        )
    }

    func testLinesAboveTheTableDoNotConfuseTheSeparator() {
        let text = "Rekening: 123\nPeriode: Sep 2026\nTanggal;Keterangan;Jumlah\n01/09/2026;Kopi;1.500,00"
        XCTAssertEqual(CSVParser.detectDelimiter(text), ";")
    }

    func testTextDecodingHandlesUTF8Windows1252AndUTF16() {
        XCTAssertEqual(CSVParser.text(from: Data("Kopi é".utf8)), "Kopi é")
        // 0xE9 alone isn't UTF-8; Windows-1252 says it is "é".
        XCTAssertEqual(CSVParser.text(from: Data([0x43, 0x61, 0x66, 0xE9])), "Café")
        let utf16 = Data([0xFF, 0xFE]) + (try! XCTUnwrap("Hi".data(using: .utf16LittleEndian)))
        XCTAssertTrue(CSVParser.text(from: utf16).hasSuffix("Hi"))
    }
}
