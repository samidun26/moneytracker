import SwiftUI
import UIKit

/// Design tokens for the retro "Duit OS" look, ported value-for-value from
/// the prototype's CSS variables in design/prototype/Main.dc.html
/// (`.theme-day`, `.duit.theme-night`, `.pal-candy`, `.acc-cobalt`).
///
/// Colors follow the system light/dark setting: day = bright paper, night =
/// soft navy. Every text/background pair used here was checked against WCAG
/// AA (4.5:1) in both modes. Only the "candy" palette is shipped; switching
/// palettes is the deferred "custom themes" item in docs/IOS_NATIVE_PLAN.md.
enum Theme {
    // MARK: Surfaces
    static let desk = Color(day: 0xA9B0F5, night: 0x171A3A)
    static let paper = Color(day: 0xFFFDF7, night: 0x1E2144)
    static let face = Color(day: 0xEFEBE3, night: 0x2A2E5C)
    static let face2 = Color(day: 0xE2DCD0, night: 0x232650)
    static let menuBar = Color(day: 0xFFFDF7, night: 0x23264F)

    // MARK: Ink and lines
    static let ink = Color(day: 0x22223B, night: 0xE6E3F4)
    static let ink2 = Color(day: 0x5C5B7A, night: 0xAAA6CC)
    static let line = Color(day: 0x22223B, night: 0x5A5FA6)
    /// Bevel highlight / shadow edges and the hard offset window shadow.
    static let hi = Color(day: 0xFFFFFF, night: 0x3B4078)
    static let lo = Color(day: 0xA7A2B4, night: 0x12142C)
    static let shadow = Color(day: 0x22223B, night: 0x0A0B1C)
    /// Faint dots on the desk background (a different opacity per mode).
    static let dot = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: 0xE6E3F4, alpha: 0.08)
            : UIColor(hex: 0x22223B, alpha: 0.16)
    })

    // MARK: Meaning
    static let positive = Color(day: 0x1A7F43, night: 0x6EE7A8)
    static let negative = Color(day: 0xC22B2B, night: 0xFF8A8A)

    // MARK: Accent (cobalt) — selection, primary button, Add
    static let accent = Color(hex: 0x3553E8)
    static let accentInk = Color.white

    // MARK: Title bars — five candy colors, always with dark ink
    static let titleColors: [Color] = [
        Color(day: 0xFFB3C7, night: 0xF58FB0), // pink
        Color(day: 0x9EE6C5, night: 0x6FD6AC), // green
        Color(day: 0xFFE08A, night: 0xF2C95C), // yellow
        Color(day: 0xA5D5FF, night: 0x7FBEF5), // blue
        Color(day: 0xCDB8FF, night: 0xB09AF5), // purple
    ]
    static let titleInk = Color(hex: 0x22223B)

    // MARK: LCD amount display
    static let lcd = Color(day: 0xD6F5C8, night: 0x0F2E2B)
    static let lcdInk = Color(day: 0x16361F, night: 0x7CF5C8)
    static let lcdGhost = Color(day: 0x16361F, night: 0x7CF5C8, opacity: 0.1)

    // MARK: Category tiles — bright in both modes, always dark ink on top
    static let tileInk = Color(hex: 0x22223B)
    static let logoCoin = Color(hex: 0xF2B11B)
}

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(opacity)))
    }

    /// A color that switches with the system appearance.
    init(day: UInt32, night: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? night : day, alpha: CGFloat(opacity))
        })
    }
}
