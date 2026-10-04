import SwiftUI

/// Draws a 16x16 pixel-art icon (see Resources/PixelIconData.swift) in the
/// current foreground style. `unit` is points per art pixel; keep it a whole
/// number (2 = a 32pt icon) so every pixel lands on the screen's pixel grid
/// and the edges stay crisp.
struct PixelIcon: View {
    var rects: PixelRects
    var unit: CGFloat = 2

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            for r in rects {
                path.addRect(CGRect(
                    x: CGFloat(r.x) * unit,
                    y: CGFloat(r.y) * unit,
                    width: CGFloat(r.w) * unit,
                    height: CGFloat(r.h) * unit
                ))
            }
            context.fill(path, with: .foreground, style: FillStyle(antialiased: false))
        }
        .frame(width: 16 * unit, height: 16 * unit)
        .accessibilityHidden(true)
    }
}

/// The Duit "D" with its coin, as in the prototype's app bar.
struct DuitLogo: View {
    var body: some View {
        ZStack {
            PixelIcon(rects: PixelIconData.logo).foregroundStyle(Theme.ink)
            PixelIcon(rects: PixelIconData.coin).foregroundStyle(Theme.logoCoin)
        }
    }
}
