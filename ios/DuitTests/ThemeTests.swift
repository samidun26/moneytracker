import XCTest
import UIKit
@testable import Duit

/// Guards the retro design layer against failures that would otherwise be
/// silent: a mistyped font name makes SwiftUI quietly fall back to the
/// system font, and a category without a pixel icon would just show an emoji.
final class ThemeTests: XCTestCase {
    func testEveryBundledFontLoadsByItsPostScriptName() {
        DuitFonts.registerAll()
        for name in DuitFonts.all {
            XCTAssertNotNil(UIFont(name: name, size: 16), "\(name) did not load — wrong file name or PostScript name")
        }
    }

    func testEveryDefaultCategoryHasAPixelIcon() {
        for item in DefaultCategories.items {
            XCTAssertNotNil(
                CategoryPixelIcon.rects(for: item.icon),
                "\(item.kind.rawValue) category \"\(item.name)\" (\(item.icon)) has no pixel icon mapped in CategoryPixelIcon"
            )
        }
    }

    func testEmojiMatchWithOrWithoutVariationSelector() {
        XCTAssertNotNil(CategoryPixelIcon.rects(for: "✈️"))
        XCTAssertNotNil(CategoryPixelIcon.rects(for: "✈"))
    }

    func testUnknownEmojiHasNoPixelIconSoItFallsBackToTheEmoji() {
        XCTAssertNil(CategoryPixelIcon.rects(for: "🦄"))
    }

    func testPixelIconsStayInsideTheSixteenBySixteenGrid() {
        for (name, rects) in PixelIconData.all {
            XCTAssertFalse(rects.isEmpty, "\(name) has no pixels")
            for r in rects {
                XCTAssertTrue(
                    r.x >= 0 && r.y >= 0 && r.w > 0 && r.h > 0 && r.x + r.w <= 16 && r.y + r.h <= 16,
                    "\(name) has a rectangle outside the 16x16 grid: \(r)"
                )
            }
        }
    }

    func testHexColorsDecodeToTheRightChannels() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hex: 0x3553E8).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0x35 / 255, accuracy: 0.001)
        XCTAssertEqual(g, 0x53 / 255, accuracy: 0.001)
        XCTAssertEqual(b, 0xE8 / 255, accuracy: 0.001)
        XCTAssertEqual(a, 1, accuracy: 0.001)
    }
}
