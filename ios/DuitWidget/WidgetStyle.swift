import SwiftUI

/// The retro colors the widgets draw with. The app's `Theme` uses dynamic
/// colors that read the user's settings, which don't carry over into a
/// widget process, so the widget picks day or night from its own
/// environment and takes the palette from the snapshot. The values are the
/// same ones as `Theme` in the app — keep them in sync.
struct WidgetColors {
    let paper: Color
    let face: Color
    let ink: Color
    let ink2: Color
    let line: Color
    let lcd: Color
    let lcdInk: Color
    let okFill: Color
    let warnFill: Color
    let overFill: Color
    let grid: Color
    let negative: Color
    let accent = Color(hex: 0x3553E8)
    let accentInk = Color.white
    let titleInk = Color(hex: 0x22223B)
    /// The palette's five title-bar colors.
    let titles: [Color]

    init(scheme: ColorScheme, palette: String) {
        let dark = scheme == .dark
        func pick(_ day: UInt32, _ night: UInt32) -> Color { Color(hex: dark ? night : day) }
        paper = pick(0xFFFDF7, 0x1E2144)
        face = pick(0xEFEBE3, 0x2A2E5C)
        ink = pick(0x22223B, 0xE6E3F4)
        ink2 = pick(0x5C5B7A, 0xAAA6CC)
        line = pick(0x22223B, 0x5A5FA6)
        lcd = pick(0xD6F5C8, 0x0F2E2B)
        lcdInk = pick(0x16361F, 0x7CF5C8)
        okFill = pick(0x2FB36A, 0x4ADE80)
        warnFill = pick(0xF2A516, 0xFACC15)
        overFill = pick(0xEF4444, 0xF87171)
        grid = Color(hex: dark ? 0xE6E3F4 : 0x22223B, opacity: 0.12)
        negative = pick(0xC22B2B, 0xFF8A8A)
        let named = PaletteName(rawValue: palette) ?? .candy
        titles = named.colors(dark: dark).titles.map { Color(hex: $0) }
    }

    func batteryFill(_ level: WidgetSnapshot.Level) -> Color {
        switch level {
        case .ok: okFill
        case .warn: warnFill
        case .low: overFill
        }
    }
}

/// The colored title bar of a window: pixel-font title, hairline underneath.
struct WidgetTitleBar: View {
    var title: String
    var tint: Color
    var colors: WidgetColors

    var body: some View {
        HStack {
            Text(title)
                .font(.pixel(11))
                .foregroundStyle(colors.titleInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .background(tint)
        .overlay(alignment: .bottom) { colors.line.frame(height: 1) }
    }
}

/// The Tanggal Tua battery: 20 cells in a sunken well.
struct WidgetBatteryBar: View {
    var cells: Int
    var fill: Color
    var colors: WidgetColors

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<WidgetSnapshot.batteryCells, id: \.self) { index in
                Rectangle().fill(index < cells ? fill : colors.grid)
            }
        }
        .padding(2.5)
        .frame(height: 18)
        .background(colors.paper)
        .overlay(Rectangle().strokeBorder(colors.line, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// A plus sign drawn from two bars (no icon font or image needed).
struct WidgetPlus: View {
    var color: Color
    var length: CGFloat = 26
    var thickness: CGFloat = 8

    var body: some View {
        ZStack {
            Rectangle().fill(color).frame(width: length, height: thickness)
            Rectangle().fill(color).frame(width: thickness, height: length)
        }
        .accessibilityHidden(true)
    }
}
