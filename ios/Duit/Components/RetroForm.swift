import SwiftUI

// Form pieces for Settings and its sheets, ported from the prototype's
// `fieldset.group`, `.opt` rows (radio / checkbox), `.field` inputs and
// the `.xbtn` close box.

// MARK: - Group

/// A bordered group with its title cut into the top edge (`fieldset.group`).
struct RetroGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.top, 14)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().strokeBorder(Theme.ink2, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.pixel(16))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 6)
                .background(Theme.paper)
                .offset(x: 8, y: -10)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 10)
    }
}

// MARK: - Option rows

/// The look of one choice in a group: a round radio or a square checkbox, a
/// label, an optional hint and an optional trailing view (the palette
/// strip). `RetroOptionRow` makes it a button; Settings also uses it bare
/// as the label of a menu.
enum RetroOptionStyle { case radio, check }

struct RetroOptionLabel<Trailing: View>: View {
    var label: String
    var hint: String?
    var isOn: Bool
    var style: RetroOptionStyle = .radio
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            mark
            Text(label)
                .font(.plex(15))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            if let hint {
                Text(hint)
                    .font(.plex(11.5))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
            trailing()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var mark: some View {
        switch style {
        case .radio:
            Circle()
                .fill(Theme.paper)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
                .overlay { if isOn { Circle().fill(Theme.accent).frame(width: 10, height: 10) } }
        case .check:
            Rectangle()
                .fill(Theme.paper)
                .frame(width: 20, height: 20)
                .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                .overlay {
                    if isOn { PixelIcon(rects: PixelIconData.check, unit: 1).foregroundStyle(Theme.accent) }
                }
        }
    }
}

extension RetroOptionLabel where Trailing == EmptyView {
    init(label: String, hint: String? = nil, isOn: Bool, style: RetroOptionStyle = .radio) {
        self.init(label: label, hint: hint, isOn: isOn, style: style, trailing: { EmptyView() })
    }
}

/// A tappable choice: `RetroOptionLabel` inside a button.
struct RetroOptionRow<Trailing: View>: View {
    var label: String
    var hint: String?
    var isOn: Bool
    var style: RetroOptionStyle = .radio
    var action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            RetroOptionLabel(label: label, hint: hint, isOn: isOn, style: style, trailing: trailing)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityValue(style == .check ? (isOn ? "On" : "Off") : "")
    }
}

extension RetroOptionRow where Trailing == EmptyView {
    init(label: String, hint: String? = nil, isOn: Bool, style: RetroOptionStyle = .radio, action: @escaping () -> Void) {
        self.init(label: label, hint: hint, isOn: isOn, style: style, action: action, trailing: { EmptyView() })
    }
}

/// The five title colors of a palette as a little strip (`.pstrip`).
struct PaletteStrip: View {
    var colors: [Color]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in color }
        }
        .frame(width: 72, height: 16)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Tappable value row

/// A row that shows a setting's current value and opens an editor when
/// tapped: "Spending money · Rp 8.500.000 ›".
struct RetroValueRow: View {
    var label: String
    var value: String
    var accessibilityHint: String = ""
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.plex(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                Text(value)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.ink2)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Text field

/// A sunken one-line text field with a small caption (`.sunk.field`).
struct RetroTextField: View {
    var caption: String
    var placeholder: String
    @Binding var text: String
    var maxLength = 40
    var capitalization: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(.plex(11, .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink2)
            TextField(caption, text: $text, prompt: Text(placeholder).foregroundStyle(Theme.ink2))
                .font(.plex(16))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onChange(of: text) {
                    if text.count > maxLength { text = String(text.prefix(maxLength)) }
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 52, alignment: .leading)
        .retroSunk()
    }
}

// MARK: - Close box and sheet frame

/// The little white "x" in a title bar that closes a sheet.
struct RetroCloseBox: View {
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("x")
                .font(.pixel(12))
                .foregroundStyle(Theme.titleInk)
                .frame(width: 22, height: 22)
                .background(Color.white)
                .overlay(Rectangle().strokeBorder(Theme.titleInk, lineWidth: 1))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A sheet dressed as a window: colored title bar with a close box, a paper
/// body. Alerts raised inside a sheet need their own `.retroAlert`, because
/// the root's alert sits underneath sheets.
struct RetroSheet<Content: View>: View {
    var title: String
    var tint: Color
    var icon: PixelRects?
    var closeLabel: String = "Close"
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar(title: title, tint: tint, icon: icon) {
                RetroCloseBox(label: closeLabel, action: onClose)
            }
            content()
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
    }
}

// MARK: - LCD amount

/// The big green LCD readout with ghost digits behind the number.
struct LCDAmount: View {
    var caption: String
    var amount: Int
    var prefix = "Rp "

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Text("888.888.888").font(.lcd(42)).foregroundStyle(Theme.lcdGhost).accessibilityHidden(true)
            Text("\(prefix)\(CurrencyFormatter.formatNumber(amount))")
                .font(.lcd(42))
                .foregroundStyle(Theme.lcdInk)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .bottomTrailing)
        .overlay(alignment: .topLeading) {
            Text(caption)
                .font(.plex(11, .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .lineLimit(1)
                .foregroundStyle(Theme.lcdInk)
                .padding(.horizontal, 10)
                .padding(.top, 7)
                .accessibilityHidden(true)
        }
        .background(Theme.lcd)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(CurrencyFormatter.formatRp(amount))
    }
}
