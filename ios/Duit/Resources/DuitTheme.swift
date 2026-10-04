import SwiftUI
import UIKit

/// Design tokens for the retro "Duit OS" look, ported value-for-value from
/// the prototype's CSS variables in design/prototype/Main.dc.html
/// (`.theme-day`, `.duit.theme-night`, `.pal-candy`, `.acc-cobalt`).
///
/// Colors follow the system light/dark setting: day = bright paper, night =
/// soft navy. Every text/background pair used here was checked against WCAG
/// AA (4.5:1) in both modes. The title-bar colors and the desk follow the
/// palette chosen in Settings (candy, arcade or sunset).
enum Theme {
    // MARK: Surfaces
    /// The backdrop behind the windows; depends on the palette.
    static let desk = Color(uiColor: UIColor { traits in
        UIColor(hex: Theme.currentPalette.colors(dark: traits.userInterfaceStyle == .dark).desk)
    })
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

    // MARK: Title bars — five palette colors, always with dark ink
    static var currentPalette: PaletteName { PaletteName(rawValue: Prefs.paletteName) ?? .candy }

    /// Title colors 1...5 (the prototype's --t1...--t5) for the current palette.
    static let titleColors: [Color] = (0..<5).map { index in
        Color(uiColor: UIColor { traits in
            UIColor(hex: Theme.currentPalette.colors(dark: traits.userInterfaceStyle == .dark).titles[index])
        })
    }
    static let titleInk = Color(hex: 0x22223B)

    // MARK: LCD amount display
    static let lcd = Color(day: 0xD6F5C8, night: 0x0F2E2B)
    static let lcdInk = Color(day: 0x16361F, night: 0x7CF5C8)
    static let lcdGhost = Color(day: 0x16361F, night: 0x7CF5C8, opacity: 0.1)

    // MARK: Category tiles — bright in both modes, always dark ink on top
    static let tileInk = Color(hex: 0x22223B)
    static let logoCoin = Color(hex: 0xF2B11B)

    // MARK: Battery cells and budget meters
    static let okFill = Color(day: 0x2FB36A, night: 0x4ADE80)
    static let warnFill = Color(day: 0xF2A516, night: 0xFACC15)
    static let overFill = Color(day: 0xEF4444, night: 0xF87171)
    /// An unlit cell / empty meter block.
    static let grid = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hex: 0xE6E3F4, alpha: 0.12)
            : UIColor(hex: 0x22223B, alpha: 0.12)
    })

    // MARK: Duit Terminal (dark in both modes, like the prototype's `.term`)
    static let terminalBackground = Color(hex: 0x16182F)
    static let terminalGreen = Color(hex: 0x9EF0C8)
    static let terminalPink = Color(hex: 0xFFB3C7)
    static let terminalError = Color(hex: 0xFF9B9B)
    static let terminalDim = Color(hex: 0x9A9CC6)
    static let terminalYellow = Color(hex: 0xFFD45C)
    static let terminalText = Color(hex: 0xF2F0FA)

    // MARK: Rubber-stamp inks
    static let redInk = Color(day: 0xD93636, night: 0xFF7B7B)
    static let greenInk = Color(day: 0x1F8F4E, night: 0x5BE39A)
    static let amberInk = Color(day: 0xC97A00, night: 0xFFC857)

    // MARK: Good / bad buttons and status chips
    static let good = Color(hex: 0x5FD08A)
    static let bad = Color(hex: 0xFF8FB8)
    static let caution = Color(hex: 0xFFD45C)
}

/// The three palettes from the prototype (`.pal-candy`, `.pal-arcade`,
/// `.pal-sunset`): five title-bar colors plus the desk behind them.
enum PaletteName: String, CaseIterable, Identifiable {
    case candy, arcade, sunset

    var id: String { rawValue }

    var label: String {
        switch self {
        case .candy: "Candy"
        case .arcade: "Arcade"
        case .sunset: "Sunset"
        }
    }

    var hint: String {
        switch self {
        case .candy: "soft pastels"
        case .arcade: "bold 90s brights"
        case .sunset: "warm 70s tones"
        }
    }

    func colors(dark: Bool) -> (titles: [UInt32], desk: UInt32) {
        switch (self, dark) {
        case (.candy, false): return ([0xFFB3C7, 0x9EE6C5, 0xFFE08A, 0xA5D5FF, 0xCDB8FF], 0xA9B0F5)
        case (.candy, true): return ([0xF58FB0, 0x6FD6AC, 0xF2C95C, 0x7FBEF5, 0xB09AF5], 0x171A3A)
        case (.arcade, false): return ([0xFF6B6B, 0x45D16F, 0xFFD23F, 0x4DA3FF, 0xB983FF], 0x2FA39A)
        case (.arcade, true): return ([0xFF6B6B, 0x4ADE80, 0xFACC15, 0x60A5FA, 0xC084FC], 0x0E2A2D)
        case (.sunset, false): return ([0xFF8C7A, 0x5CC6B8, 0xF2C14E, 0xFFA552, 0xD49BD6], 0xF2B48A)
        case (.sunset, true): return ([0xF2786A, 0x3FB5A6, 0xE8B23A, 0xF29441, 0xC585C8], 0x1C1733)
        }
    }

    /// The day colors as a swatch strip for the Settings picker.
    var swatches: [Color] { colors(dark: false).titles.map { Color(hex: $0) } }
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
