import SwiftUI

// Window chrome for the retro look: the dotted desk, the app bar with its
// five-color stripe, windows with colored title bars and hard offset
// shadows, and the bottom taskbar. Ported from the prototype's `.desktop`,
// `.appbar`, `.win`/`.tbar` and `.taskbar` CSS.

// MARK: - Desk

/// The lavender (day) / navy (night) backdrop with the faint dot texture.
struct DeskBackground: View {
    var body: some View {
        ZStack {
            Theme.desk
            Canvas { context, size in
                var dots = Path()
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        dots.addRect(CGRect(x: x, y: y, width: 1, height: 1))
                        x += 6
                    }
                    y += 6
                }
                context.fill(dots, with: .color(Theme.dot), style: FillStyle(antialiased: false))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Title bar and window

/// A colored title bar: pixel-font title, dotted leader line, optional
/// trailing control (a count badge, a close box...).
struct RetroTitleBar<Trailing: View>: View {
    var title: String
    var tint: Color
    var ink: Color = Theme.titleInk
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.pixel(16))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            HLine()
                .stroke(ink.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [1.5, 3.5]))
                .frame(height: 4)
                .accessibilityHidden(true)
            trailing()
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 8)
        .frame(minHeight: 32)
        .frame(maxWidth: .infinity)
        .background(tint)
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
    }
}

extension RetroTitleBar where Trailing == EmptyView {
    init(title: String, tint: Color, ink: Color = Theme.titleInk) {
        self.init(title: title, tint: tint, ink: ink, trailing: { EmptyView() })
    }
}

/// A window: title bar on top, paper body, 1px outline, 3pt hard shadow.
struct RetroWindow<Content: View, Trailing: View>: View {
    var title: String
    var tint: Color
    var ink: Color = Theme.titleInk
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar(title: title, tint: tint, ink: ink, trailing: trailing)
            content()
        }
        .background(Theme.paper)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .background { Theme.shadow.offset(x: 3, y: 3) }
    }
}

extension RetroWindow where Trailing == EmptyView {
    init(title: String, tint: Color, ink: Color = Theme.titleInk, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, tint: tint, ink: ink, trailing: { EmptyView() }, content: content)
    }
}

/// The small dark pill on a title bar that shows a count (`.tcount`).
struct CountBadge: View {
    var count: Int

    var body: some View {
        Text("\(count)")
            .font(.plex(12, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background(Theme.titleInk, in: Capsule())
            .accessibilityLabel("\(count) items")
    }
}

// MARK: - App bar and taskbar

/// Logo + screen title, with the five-color palette stripe underneath.
struct RetroAppBar: View {
    var title: String

    var body: some View {
        HStack(spacing: 10) {
            DuitLogo()
            Text(title)
                .font(.pixel(18))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6) // room for the stripe
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity)
        .background(Theme.menuBar.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { PaletteStripe() }
    }
}

struct PaletteStripe: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Theme.titleColors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .frame(height: 6)
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
        .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
        .accessibilityHidden(true)
    }
}

/// The bottom bar. Only "Add" exists for now; the prototype's other four
/// tabs (Today, Activity, Insights, Settings) arrive with their screens.
struct RetroTaskbar: View {
    var onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 4) {
                PixelIcon(rects: PixelIconData.plus, unit: 1)
                Text("Add")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(RetroButtonStyle(kind: .accent))
        .accessibilityLabel("Add transaction")
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 9)
        .background(Theme.face.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }
}
