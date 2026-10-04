import SwiftUI

extension CategoryColor {
    /// Tile colors from the retro prototype's `.cc-*` classes — bright in
    /// both light and dark so the dark pixel icon on top always reads.
    /// `teal` and `cyan` have no prototype equivalent: teal reuses the
    /// sunset palette's #5CC6B8 and cyan is a light blue between mint and
    /// blue.
    var color: Color {
        switch self {
        case .red: Color(hex: 0xFF7272)
        case .orange: Color(hex: 0xFF9B54)
        case .yellow: Color(hex: 0xFFD45C)
        case .green: Color(hex: 0x5FD08A)
        case .mint: Color(hex: 0x5ED6C4)
        case .teal: Color(hex: 0x5CC6B8)
        case .cyan: Color(hex: 0x7FD3EE)
        case .blue: Color(hex: 0x6AAEFF)
        case .indigo: Color(hex: 0xA38BFF)
        case .purple: Color(hex: 0xD38BFF)
        case .pink: Color(hex: 0xFF8FB8)
        case .brown: Color(hex: 0xD9A066)
        case .gray: Color(hex: 0xB8B6CC)
        }
    }
}

/// Maps the emoji a Category stores to the prototype's pixel icons. The
/// database keeps the emoji (no schema change); this only decides how it's
/// drawn. An emoji with no pixel equivalent — e.g. one a user picks later —
/// is shown as the emoji itself.
enum CategoryPixelIcon {
    static func rects(for emoji: String) -> PixelRects? {
        table[normalize(emoji)]
    }

    /// Emoji sometimes carry an invisible variation selector (U+FE0F);
    /// drop it so "✈️" and "✈" match.
    private static func normalize(_ emoji: String) -> String {
        emoji.replacingOccurrences(of: "\u{FE0F}", with: "")
    }

    private static let table: [String: PixelRects] = {
        let pairs: [(String, PixelRects)] = [
            ("🍜", PixelIconData.food),
            ("☕", PixelIconData.coffee),
            ("🛒", PixelIconData.cart),
            ("🛵", PixelIconData.car),
            ("🏠", PixelIconData.building),
            ("💡", PixelIconData.bulb),
            ("📺", PixelIconData.tv),
            ("🛍️", PixelIconData.bag),
            ("🎬", PixelIconData.star),
            ("💊", PixelIconData.cross),
            ("📚", PixelIconData.book),
            ("👨‍👩‍👧", PixelIconData.family),
            ("🎁", PixelIconData.gift),
            ("✈️", PixelIconData.plane),
            ("📦", PixelIconData.box),
            ("💼", PixelIconData.briefcase),
            ("🎉", PixelIconData.gift),
            ("💻", PixelIconData.chart),
            ("📈", PixelIconData.chart),
            ("↩️", PixelIconData.transfer),
            ("💰", PixelIconData.cash),
        ]
        return Dictionary(pairs.map { (CategoryPixelIcon.normalize($0.0), $0.1) }, uniquingKeysWith: { first, _ in first })
    }()
}

/// A category tile: a pixel icon (or emoji fallback) on a bright square with
/// a 1px outline and a light bevel — the prototype's `.tile`.
struct IconBadge: View {
    var icon: String
    var color: CategoryColor
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let rects = CategoryPixelIcon.rects(for: icon) {
                PixelIcon(rects: rects, unit: 2).foregroundStyle(Theme.tileInk)
            } else {
                Text(icon).font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .background(color.color)
        .overlay { BevelOverlay(topLeft: .white.opacity(0.5), bottomRight: .black.opacity(0.14)) }
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
