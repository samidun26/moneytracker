import SwiftUI
import CoreText

/// The three fonts the retro design uses, bundled in Resources/Fonts (all SIL
/// Open Font License 1.1 — the license texts ship next to the font files):
/// - Silkscreen — pixel font for titles, buttons and tabs
/// - VT323 — the LCD amount and keypad digits
/// - IBM Plex Mono — body text
///
/// They're registered at launch with CoreText rather than listed in
/// Info.plist, so no extra build configuration is needed. A wrong name makes
/// SwiftUI silently fall back to the system font, so
/// DuitTests/ThemeTests.swift checks every name below actually loads.
enum DuitFonts {
    /// PostScript names — also the bundled file names (without ".ttf").
    static let silkscreenRegular = "Silkscreen-Regular"
    static let silkscreenBold = "Silkscreen-Bold"
    static let vt323 = "VT323-Regular"
    static let plexRegular = "IBMPlexMono-Regular"
    static let plexMedium = "IBMPlexMono-Medium"
    static let plexSemiBold = "IBMPlexMono-SemiBold"
    static let plexBold = "IBMPlexMono-Bold"

    static let all = [
        silkscreenRegular, silkscreenBold, vt323,
        plexRegular, plexMedium, plexSemiBold, plexBold,
    ]

    /// Safe to call more than once (re-registering an already-registered
    /// font is a harmless no-op).
    static func registerAll(bundle: Bundle = .main) {
        for name in all {
            guard let url = bundle.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Missing bundled font file \(name).ttf")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

enum PlexWeight {
    case regular, medium, semibold, bold

    var fontName: String {
        switch self {
        case .regular: DuitFonts.plexRegular
        case .medium: DuitFonts.plexMedium
        case .semibold: DuitFonts.plexSemiBold
        case .bold: DuitFonts.plexBold
        }
    }
}

/// Sizes scale with the user's Dynamic Type setting; layout uses minimum
/// heights (never fixed ones) so larger text grows its container.
extension Font {
    /// Silkscreen — titles, buttons, tabs. Draws capitals only, by design.
    static func pixel(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? DuitFonts.silkscreenBold : DuitFonts.silkscreenRegular, size: size, relativeTo: .body)
    }

    /// VT323 — the LCD amount and keypad digits.
    static func lcd(_ size: CGFloat) -> Font {
        .custom(DuitFonts.vt323, size: size, relativeTo: .title)
    }

    /// IBM Plex Mono — body text.
    static func plex(_ size: CGFloat, _ weight: PlexWeight = .regular) -> Font {
        .custom(weight.fontName, size: size, relativeTo: .body)
    }
}
