import SwiftUI
import SwiftData

/// The home screen, after the prototype's "Today": the Tanggal Tua battery,
/// a single To do list, and Recent.
struct TodayView: View {
    let ledger: Ledger
    var onEdit: (UUID) -> Void
    var onGoActivity: () -> Void
    var onGoSettings: () -> Void
    var onCheckBalance: (UUID) -> Void
    var onPayday: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                TanggalTuaWindow(ledger: ledger, onGoSettings: onGoSettings, onPayday: onPayday)
                TodoWindow(ledger: ledger, onCheckBalance: onCheckBalance)
                RecentWindow(ledger: ledger, onEdit: onEdit, onSeeAll: onGoActivity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Tanggal Tua

private struct TanggalTuaWindow: View {
    let ledger: Ledger
    var onGoSettings: () -> Void
    var onPayday: () -> Void

    var body: some View {
        RetroWindow(title: "Tanggal Tua", tint: Theme.titleColors[2], icon: PixelIconData.battery) {
            if let battery = ledger.battery {
                filled(battery)
            } else {
                setup
            }
        }
    }

    private func filled(_ b: Battery) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                BatteryBar(battery: b)
                Text("\(b.percent)%")
                    .font(.pixel(18))
                    .foregroundStyle(b.isPowerSaving ? Theme.negative : Theme.ink)
                    .frame(width: 54, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(CurrencyFormatter.formatRp(b.allowance))
                    .font(.pixel(26))
                    .foregroundStyle(Theme.ink)
                Text(" / day")
                    .font(.pixel(14))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.top, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(CurrencyFormatter.formatRp(b.allowance)) a day")
            Text(b.summary(payday: ledger.period.nextPayday))
                .font(.plex(12.5))
                .foregroundStyle(Theme.ink2)
                .padding(.top, 2)
            if b.isPowerSaving {
                Text("Power saving · spend gently")
                    .font(.plex(11, .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.titleInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.bad)
                    .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                    .padding(.top, 10)
            }
            if ledger.needsPaydaySplit {
                Button(action: onPayday) {
                    Text("Payday! Split your salary →")
                        .font(.plex(13, .semibold))
                        .underline()
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(14)
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tanggal Tua is a battery that drains toward payday. Tell Duit how much you can spend each month and it shows what is safe to spend per day.")
                .font(.plex(12.5))
                .foregroundStyle(Theme.ink2)
            Button("Set spending money", action: onGoSettings)
                .buttonStyle(RetroButtonStyle(small: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

// MARK: - To do

private struct TodoWindow: View {
    let ledger: Ledger
    var onCheckBalance: (UUID) -> Void

    @Environment(\.modelContext) private var context
    @State private var stamps: [String: Stamp] = [:]

    enum Stamp {
        case paid, worth, regret

        var text: String {
            switch self {
            case .paid: "Paid"
            case .worth: "Worth it"
            case .regret: "Nyesel"
            }
        }
        var ink: Color { self == .worth ? Theme.greenInk : Theme.redInk }
        var tilt: Double {
            switch self {
            case .paid: 6
            case .worth: 3
            case .regret: -9
            }
        }
    }

    var body: some View {
        let items = ledger.todoItems()
        let open = items.filter { stamps[$0.id] == nil }.count
        RetroWindow(title: "To do", tint: Theme.titleColors[0], icon: PixelIconData.hourglass) {
            if open > 0 { CountBadge(count: open) }
        } content: {
            if items.isEmpty {
                Text("All caught up. Nothing needs you today.")
                    .font(.plex(13))
                    .foregroundStyle(Theme.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { DottedDivider() }
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: Ledger.TodoItem) -> some View {
        let stamp = stamps[item.id]
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                PixelTile(rects: item.icon, fallback: item.emoji, color: item.color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.plex(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(item.sub)
                        .font(.plex(11.5, item.late ? .bold : .regular))
                        .foregroundStyle(item.late ? Theme.negative : Theme.ink2)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if stamp == nil, let label = singleActionLabel(item) {
                    Button(label) { act(item) }
                        .buttonStyle(RetroButtonStyle(small: true))
                        .accessibilityLabel(accessibilityLabel(item))
                }
            }
            if stamp == nil, case .worth(let id) = item.kind {
                HStack(spacing: 10) {
                    Button("Worth it") { rate(item, id: id, .worth) }
                        .buttonStyle(RetroButtonStyle(kind: .good, small: true))
                        .frame(maxWidth: .infinity)
                    Button("Nyesel") { rate(item, id: id, .regret) }
                        .buttonStyle(RetroButtonStyle(kind: .bad, small: true))
                        .frame(maxWidth: .infinity)
                }
                .padding(.leading, 50)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .trailing) {
            if let stamp { StampView(text: stamp.text, ink: stamp.ink, tilt: stamp.tilt).padding(.trailing, 14) }
        }
        .contextMenu {
            if case .bill(let ruleID, let date) = item.kind, let rule = ledger.rules.first(where: { $0.id == ruleID }) {
                Button("Skip this one") { RecurringPoster.skip(rule, on: date, in: context) }
            }
        }
    }

    private func singleActionLabel(_ item: Ledger.TodoItem) -> String? {
        switch item.kind {
        case .bill: "Paid"
        case .balance: "Check"
        case .worth: nil
        }
    }

    private func accessibilityLabel(_ item: Ledger.TodoItem) -> String {
        switch item.kind {
        case .bill: "Mark \(item.title) as paid"
        case .balance: item.title
        case .worth: ""
        }
    }

    private func act(_ item: Ledger.TodoItem) {
        switch item.kind {
        case .bill(let ruleID, let date):
            guard let rule = ledger.rules.first(where: { $0.id == ruleID }) else { return }
            stamps[item.id] = .paid
            Task {
                try? await Task.sleep(for: .milliseconds(950))
                RecurringPoster.markPaid(rule, on: date, in: context)
                stamps[item.id] = nil
            }
        case .balance(let accountID):
            onCheckBalance(accountID)
        case .worth:
            break
        }
    }

    private func rate(_ item: Ledger.TodoItem, id: UUID, _ rating: WorthRating) {
        guard stamps[item.id] == nil else { return }
        stamps[item.id] = rating == .worth ? .worth : .regret
        Task {
            try? await Task.sleep(for: .milliseconds(950))
            EntryWriter.rate(id: id, rating, in: context)
            stamps[item.id] = nil
        }
    }
}

// MARK: - Recent

private struct RecentWindow: View {
    let ledger: Ledger
    var onEdit: (UUID) -> Void
    var onSeeAll: () -> Void

    var body: some View {
        RetroWindow(title: "Recent", tint: Theme.titleColors[3], icon: PixelIconData.activity) {
            VStack(spacing: 0) {
                let recent = Array(ledger.entries.prefix(5))
                if recent.isEmpty {
                    Text("Nothing logged yet. Tap Add to log your first expense.")
                        .font(.plex(13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 22)
                } else {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { DottedDivider() }
                        Button { onEdit(entry.id) } label: { EntryRow(entry: entry) }
                            .buttonStyle(RowPressStyle())
                    }
                }
                Button(action: onSeeAll) {
                    Text("See all activity")
                        .font(.pixel(14))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.face)
                        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
