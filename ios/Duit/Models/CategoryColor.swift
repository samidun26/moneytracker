import Foundation

/// Named category colors — mirrors the reference web app's `ColorName`
/// (src/db/types.ts `COLOR_NAMES`) so the same palette carries over to the
/// native retro/vintage design system.
enum CategoryColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, gray
}
