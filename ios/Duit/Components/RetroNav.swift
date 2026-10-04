import SwiftUI

/// The four screens behind the taskbar (Add is a button, not a screen).
enum AppTab: String, CaseIterable, Identifiable {
    case today, activity, insights, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .activity: "Activity"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var icon: PixelRects {
        switch self {
        case .today: PixelIconData.home
        case .activity: PixelIconData.activity
        case .insights: PixelIconData.chart
        case .settings: PixelIconData.panel
        }
    }

    /// Which of the prototype's --ti1...--ti4 colors tints the icon.
    var inkIndex: Int {
        switch self {
        case .today: 0
        case .activity: 1
        case .insights: 2
        case .settings: 3
        }
    }
}

// MARK: - App bar

/// Logo, screen title, the profile chip and a tiny battery readout, over the
/// palette stripe (the prototype's `.appbar`). Tapping the battery goes back to Today.
struct RetroAppBar: View {
    var title: String
    var battery: Battery?
    /// The open profile; tapping its chip opens the profile switcher.
    var profile: Profile?
    var onBattery: () -> Void = {}
    var onProfile: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            DuitLogo(points: 28)
            Text(title)
                .font(.pixel(18))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityAddTraits(.isHeader)
            if let profile {
                ProfilePill(profile: profile, action: onProfile)
            }
            Spacer(minLength: 0)
            if let battery {
                Button(action: onBattery) {
                    HStack(spacing: 6) {
                        HStack(spacing: 0) {
                            Rectangle().frame(width: 24 * battery.fraction)
                            Spacer(minLength: 0)
                        }
                        .padding(1)
                        .frame(width: 26, height: 13)
                        .overlay(Rectangle().strokeBorder(lineWidth: 1))
                        Text("\(battery.percent)%")
                            .font(.plex(13, .bold))
                    }
                    .foregroundStyle(battery.isPowerSaving ? Theme.negative : Theme.ink2)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(battery.accessibilityLabel)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.bottom, 6) // room for the stripe
        .frame(minHeight: 54)
        .frame(maxWidth: .infinity)
        .background(Theme.menuBar.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { PaletteStripe() }
    }
}

// MARK: - Taskbar

/// The bottom bar: Today, Activity, a raised accent Add, Insights, Settings.
struct RetroTaskbar: View {
    @Binding var selection: AppTab
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            tab(.today)
            tab(.activity)
            addButton
            tab(.insights)
            tab(.settings)
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 9)
        .background(Theme.face.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }

    private func tab(_ tab: AppTab) -> some View {
        let on = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                PixelIcon(rects: tab.icon, points: 24)
                    .foregroundStyle(Theme.tabInks[tab.inkIndex])
                Text(tab.title)
                    .font(.plex(10.5, .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(TaskbarButtonStyle(selected: on))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var addButton: some View {
        Button(action: onAdd) {
            VStack(spacing: 2) {
                PixelIcon(rects: PixelIconData.plus, points: 24)
                Text("Add").font(.plex(10.5, .bold))
            }
            .foregroundStyle(Theme.accentInk)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(TaskbarButtonStyle(selected: false, accent: true))
        .accessibilityLabel("Add a transaction")
    }
}

/// A raised tab that sinks when pressed or selected (`.tb`, `.tb-on`, `.tb-new`).
struct TaskbarButtonStyle: ButtonStyle {
    var selected: Bool
    var accent = false

    func makeBody(configuration: Configuration) -> some View {
        let sunk = configuration.isPressed || selected
        let shape = RoundedRectangle(cornerRadius: 4)
        return configuration.label
            .background(accent ? Theme.accent : (selected ? Theme.paper : Theme.face))
            .overlay {
                if accent {
                    BevelOverlay(
                        topLeft: .white.opacity(configuration.isPressed ? 0.25 : 0.35),
                        bottomRight: .black.opacity(configuration.isPressed ? 0.35 : 0.25)
                    )
                } else {
                    BevelOverlay(topLeft: sunk ? Theme.lo : Theme.hi, bottomRight: sunk ? Theme.hi : Theme.lo)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.line, lineWidth: 1))
    }
}
