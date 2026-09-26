import XCTest
@testable import Duit

final class KeypadTests: XCTestCase {
    func testDigitsAppend() {
        XCTAssertEqual(applyKey(0, .five), 5)
        XCTAssertEqual(applyKey(5, .zero), 50)
        XCTAssertEqual(applyKey(12, .triple), 12_000)
    }

    func testClampsAtMax() {
        XCTAssertEqual(applyKey(999_999_999_999, .one), 999_999_999_999)
    }

    func testBackspace() {
        XCTAssertEqual(applyKey(1_234, .back), 123)
        XCTAssertEqual(applyKey(0, .back), 0)
    }

    func testClear() {
        XCTAssertEqual(applyKey(500, .clear), 0)
    }
}
