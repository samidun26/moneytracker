import SwiftUI

// Feedback and small controls from the prototype: rubber stamps, the toast
// with Undo, the retro alert, chips, popup menus, color dots, battery cells.

// MARK: - Rubber stamp

/// "SAVED", "PAID", "WORTH IT"... thumped onto the screen for an action
/// (the prototype's `.stamp`). Purely decorative; it ignores touches.
struct StampView: View {
    enum Size { case medium, large }

    var text: String
    var ink: Color
    var tilt: Double = -4
    var size: Size = .medium

    @State private var landed = false

    var body: some View {
        Text(text)
            .font(.pixel(size == .large ? 30 : 17))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(ink)
            .padding(.horizontal, size == .large ? 16 : 10)
            .padding(.vertical, size == .large ? 8 : 5)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(ink, lineWidth: 2))
            .padding(3)
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(ink, lineWidth: 2))
            .rotationEffect(.degrees(tilt))
            .scaleEffect(landed ? 1 : 2.4)
            .opacity(landed ? 0.92 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { landed = true }
            }
    }
}

// MARK: - Toast

/// A dark note with an optional Undo, shown above the taskbar.
struct ToastView: View {
    var message: Toaster.Message
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(message.text)
                .font(.plex(13.5, .semibold))
                .foregroundStyle(Theme.terminalText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if message.undo != nil {
                Button("Undo", action: onUndo)
                    .buttonStyle(ToastButtonStyle())
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(minHeight: 52)
        .background(Color(hex: 0x22223B))
        .overlay(Rectangle().strokeBorder(Color(hex: 0x5A5FA6), lineWidth: 1))
        .background { Color(hex: 0x0A0B1C, opacity: 0.45).offset(x: 3, y: 3) }
        .accessibilityElement(children: .contain)
    }
}

private struct ToastButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pixel(14))
            .foregroundStyle(Color(hex: 0x22223B))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(configuration.isPressed ? Color(hex: 0xF2B11B) : Color(hex: 0xFFD45C))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

// MARK: - Retro alert

struct RetroAlertContent: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var icon: PixelRects
    /// nil = an info box with just OK. Set = a question: this button runs
    /// `action`, and Cancel (the safe default) closes.
    var confirmLabel: String?
    var action: (() -> Void)?
}

extension View {
    /// The prototype's `.alert`: a double-bordered dialog over a dimmed screen.
    func retroAlert(_ alert: Binding<RetroAlertContent?>) -> some View {
        overlay {
            if let content = alert.wrappedValue {
                RetroAlertView(content: content) { alert.wrappedValue = nil }
                    .transition(.opacity)
            }
        }
    }
}

private struct RetroAlertView: View {
    var content: RetroAlertContent
    var close: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x141633, opacity: 0.45).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    PixelIcon(rects: content.icon, unit: 3)
                        .foregroundStyle(Theme.ink)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(content.title)
                            .font(.pixel(16))
                            .foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text(content.message)
                            .font(.plex(12.5))
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 14)
                HStack(spacing: 14) {
                    Spacer()
                    if let label = content.confirmLabel {
                        Button(label) {
                            content.action?()
                            close()
                        }
                        .buttonStyle(RetroButtonStyle())
                        Button("Cancel", action: close)
                            .buttonStyle(RetroButtonStyle(kind: .primary))
                    } else {
                        Button("OK", action: close)
                            .buttonStyle(RetroButtonStyle(kind: .primary))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .background(Theme.paper)
            .overlay(Rectangle().inset(by: 3).strokeBorder(Theme.line, lineWidth: 1))
            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
            .background { Theme.shadow.offset(x: 3, y: 3) }
            .padding(.horizontal, 20)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}

// MARK: - Chips, popups, dots

/// A raised pill button (`.chip`): suggestions, examples, quick answers.
struct RetroChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 4)
        return configuration.label
            .font(.plex(13, .semibold))
            .foregroundStyle(pressed ? Theme.accentInk : Theme.ink)
            .padding(.horizontal, 11)
            .frame(minHeight: 40)
            .background(pressed ? Theme.accent : Theme.face)
            .overlay { BevelOverlay(topLeft: pressed ? Theme.lo : Theme.hi, bottomRight: pressed ? Theme.hi : Theme.lo) }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// A read-only chip (`.pchip`): what the Terminal will log.
struct RetroPill: View {
    var text: String
    var dot: Color?

    var body: some View {
        HStack(spacing: 6) {
            if let dot { ColorDot(color: dot) }
            Text(text)
                .font(.plex(12, .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Theme.face)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct ColorDot: View {
    var color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// The label of a menu button (`.popup`): text and a small ▼.
struct RetroPopupLabel: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.plex(14, .semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .accessibilityHidden(true)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity)
        .background(Theme.paper)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .background { Theme.shadow.offset(x: 2, y: 2) }
    }
}

// MARK: - Battery cells

/// The Tanggal Tua battery body: 20 cells in a sunken well, with a nub.
struct BatteryBar: View {
    var battery: Battery
    var height: CGFloat = 36

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<Battery.cellCount, id: \.self) { index in
                Rectangle()
                    .fill(index < battery.filledCells ? fill : Theme.grid)
            }
        }
        .padding(3)
        .frame(height: height)
        .retroSunk()
        .overlay(alignment: .trailing) {
            Theme.line.frame(width: 6, height: 16).offset(x: 6)
        }
        .padding(.trailing, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(battery.accessibilityLabel)
    }

    private var fill: Color {
        switch battery.level {
        case .ok: Theme.okFill
        case .warn: Theme.warnFill
        case .low: Theme.overFill
        }
    }
}

/// A 20-block budget meter (`.meter` / `.blk`).
struct BudgetMeter: View {
    var progress: BudgetCalculator.Progress

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<BudgetCalculator.blockCount, id: \.self) { index in
                Rectangle().fill(index < progress.filledBlocks ? fill : Theme.grid)
            }
        }
        .padding(2)
        .frame(height: 16)
        .retroSunk()
    }

    private var fill: Color {
        switch progress.status {
        case .ok: Theme.okFill
        case .warn: Theme.warnFill
        case .over: Theme.overFill
        }
    }
}

// MARK: - LCD stat box

/// A small green LCD with a caption and a big number (the prototype's
/// `.lcd.statbox`): Spent / Income, Worth it / Nyesel.
struct LCDStatBox: View {
    var caption: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(.plex(11, .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .lineLimit(1)
            Text(value)
                .font(.lcd(30))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(Theme.lcdInk)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lcd)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption)
        .accessibilityValue(value)
    }
}

// MARK: - Status chip

/// "ON TRACK" / "CAREFUL" / "OVER" beside a budget.
struct BudgetStatusChip: View {
    var status: BudgetStatus

    var body: some View {
        Text(status.label)
            .font(.plex(10.5, .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Theme.titleInk)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(fill)
            .overlay(Rectangle().strokeBorder(Theme.titleInk, lineWidth: 1))
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch status {
        case .ok: Theme.good
        case .warn: Theme.caution
        case .over: Theme.bad
        }
    }
}
