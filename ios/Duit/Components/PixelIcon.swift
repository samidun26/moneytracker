import SwiftUI

/// Draws a 16x16 pixel-art icon (see Resources/PixelIconData.swift) in the
/// current foreground style.
///
/// Give either `unit` (points per art pixel; keep it whole so edges stay
/// crisp: 2 = a 32pt icon) or `points` (the icon's approximate size) — with
/// `points` the pixel size is rounded to whole *device* pixels, so a 24pt icon
/// is exactly 24pt on a 2x screen and 26.7pt (5 device pixels per art pixel)
/// on a 3x screen, never blurry or uneven.
struct PixelIcon: View {
    var rects: PixelRects
    var unit: CGFloat = 2
    var points: CGFloat?

    @Environment(\.displayScale) private var displayScale

    private var resolvedUnit: CGFloat {
        guard let points else { return unit }
        let scale = max(1, displayScale)
        return max(1, (points * scale / 16).rounded()) / scale
    }

    var body: some View {
        let u = resolvedUnit
        Canvas { context, _ in
            var path = Path()
            for r in rects {
                path.addRect(CGRect(
                    x: CGFloat(r.x) * u,
                    y: CGFloat(r.y) * u,
                    width: CGFloat(r.w) * u,
                    height: CGFloat(r.h) * u
                ))
            }
            context.fill(path, with: .foreground, style: FillStyle(antialiased: false))
        }
        .frame(width: 16 * u, height: 16 * u)
        .accessibilityHidden(true)
    }
}

/// The Duit "D" with its coin, as in the prototype's app bar.
struct DuitLogo: View {
    var points: CGFloat = 24

    var body: some View {
        ZStack {
            PixelIcon(rects: PixelIconData.logo, points: points).foregroundStyle(Theme.ink)
            PixelIcon(rects: PixelIconData.coin, points: points).foregroundStyle(Theme.logoCoin)
        }
    }
}
