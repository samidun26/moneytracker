import SwiftUI

// Building blocks for the retro look, ported from the prototype's CSS
// (`.btn`, `.btn-def`, `.key`, `.tab`, `.sunk`, dotted row dividers).

// MARK: - Bevel

/// The 1px light/dark inner edges that make a surface look raised (or
/// pressed, when the two colors are swapped) — the prototype's
/// `box-shadow: inset 1px 1px 0 hi, inset -1px -1px 0 lo`.
struct BevelOverlay: View {
    var topLeft: Color
    var bottomRight: Color
    var width: CGFloat = 1

    var body: some View {
        ZStack {
            Rectangle().fill(topLeft)
                .frame(height: width).frame(maxHeight: .infinity, alignment: .top)
            Rectangle().fill(topLeft)
                .frame(width: width).frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(bottomRight)
                .frame(height: width).frame(maxHeight: .infinity, alignment: .bottom)
            Rectangle().fill(bottomRight)
                .frame(width: width).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Lines

struct HLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// A 1px dotted divider between list rows (the prototype's `border-top: 1px dotted`).
struct DottedDivider: View {
    var body: some View {
        HLine()
            .stroke(Theme.ink2, style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
            .frame(height: 1)
    }
}

// MARK: - Sunken field

extension View {
    /// A recessed input well — the prototype's `.sunk`.
    func retroSunk() -> some View {
        self
            .background(Theme.paper)
            .overlay { BevelOverlay(topLeft: Theme.lo, bottomRight: Theme.hi) }
            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
    }
}

// MARK: - Buttons

/// Raised bevel buttons that sink when pressed.
/// - `plain`: grey face, pixel-font label
/// - `primary`: accent fill with the double outline ring (the default action, e.g. Save)
/// - `accent`: accent fill, no ring (the taskbar's Add)
/// - `key`: keypad digit — LCD font, thicker bottom edge, drops 2pt when pressed
/// - `danger`: plain, with a red label
/// - `good` / `bad`: green "Worth it" / pink "Nyesel"
struct RetroButtonStyle: ButtonStyle {
    enum Kind { case plain, primary, accent, key, danger, good, bad }
    var kind: Kind = .plain
    /// The prototype's `.btn-sm`: a little narrower and smaller type.
    var small = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let radius: CGFloat = kind == .primary ? 7 : (kind == .accent ? 4 : 5)
        let shape = RoundedRectangle(cornerRadius: radius)
        let filled = kind == .primary || kind == .accent
        let tinted: Color? = kind == .good ? Theme.good : (kind == .bad ? Theme.bad : nil)

        let button = configuration.label
            .font(kind == .key ? .lcd(30) : .pixel(small ? 14 : 16))
            .foregroundStyle(foreground)
            .frame(minHeight: 44)
            .frame(maxWidth: kind == .key ? CGFloat.infinity : nil)
            .padding(.horizontal, kind == .key ? 0 : (small ? 12 : 16))
            .background(filled ? Theme.accent : (tinted ?? (pressed ? Theme.face2 : Theme.face)))
            .overlay {
                if filled {
                    BevelOverlay(
                        topLeft: .white.opacity(pressed ? 0.25 : 0.35),
                        bottomRight: .black.opacity(pressed ? 0.35 : 0.25)
                    )
                } else {
                    BevelOverlay(topLeft: pressed ? Theme.lo : Theme.hi, bottomRight: pressed ? Theme.hi : Theme.lo)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))

        Group {
            if kind == .primary {
                // 2pt paper gap, then a 2pt line ring around the button.
                button
                    .padding(2)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 9))
                    .padding(2)
                    .background(Theme.line, in: RoundedRectangle(cornerRadius: 11))
            } else if kind == .key {
                button
                    .background(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5).fill(Theme.line).offset(y: pressed ? 0 : 2)
                    }
                    .offset(y: pressed ? 2 : 0)
                    .padding(.bottom, 2)
            } else {
                button
                    .offset(y: pressed ? 1 : 0)
            }
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .accent: Theme.accentInk
        case .danger: Theme.negative
        case .good, .bad: Theme.titleInk
        default: Theme.ink
        }
    }
}

// MARK: - Tabs

/// Folder-style tabs (the prototype's `.tabs`): the selected tab is the same
/// paper color as the window body and "opens" into it.
struct RetroTabs<Value: Hashable>: View {
    var items: [Value]
    var label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.line.frame(height: 1)
            HStack(spacing: -1) {
                ForEach(items, id: \.self) { item in
                    let on = item == selection
                    let shape = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6)
                    Button {
                        selection = item
                    } label: {
                        Text(label(item))
                            .font(.pixel(14))
                            .foregroundStyle(on ? Theme.ink : Theme.ink2)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(on ? Theme.paper : Theme.face2, in: shape)
                            .overlay(shape.stroke(Theme.line, lineWidth: 1))
                            .overlay(alignment: .bottom) {
                                // Hide the divider under the selected tab.
                                if on { Theme.paper.frame(height: 1).padding(.horizontal, 1) }
                            }
                    }
                    .buttonStyle(.plain)
                    .zIndex(on ? 1 : 0)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
