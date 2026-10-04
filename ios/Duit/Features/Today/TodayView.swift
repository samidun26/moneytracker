import SwiftUI
import SwiftData

/// The home screen, after the prototype's "Today": the Tanggal Tua battery,
/// the Duit Terminal, a single To do list, and Recent.
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
                TerminalWindow(ledger: ledger)
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

// MARK: - Duit Terminal

private struct TerminalWindow: View {
    let ledger: Ledger

    @Environment(\.modelContext) private var context
    @Environment(Toaster.self) private var toaster
    @State private var command = ""
    @State private var lines = TermLine.hint
    @State private var stamped = false

    struct TermLine: Identifiable {
        enum Kind { case dim, input, ok, error }
        let id = UUID()
        let kind: Kind
        let text: String

        static let hint = [
            TermLine(kind: .dim, text: "Type what you spent, like mie ayam 22rb."),
            TermLine(kind: .dim, text: "Ask sisa? or grab vs gojek. Type help for more."),
        ]
    }

    private let examples = ["mie ayam 22rb", "es teh goceng", "sisa?", "grab vs gojek"]

    private var trimmed: String { command.trimmingCharacters(in: .whitespaces) }
    private var asking: Bool { !trimmed.isEmpty && TerminalEngine.isQuestion(trimmed) }

    var body: some View {
        let parsed: ParsedEntry? = (trimmed.isEmpty || asking) ? nil : SlangParser.parse(trimmed, context: ledger.parseContext())
        RetroWindow(title: "Duit Terminal", tint: Theme.titleColors[4], icon: PixelIconData.term) {
            VStack(alignment: .leading, spacing: 10) {
                terminal
                if let parsed { preview(parsed) }
                if trimmed.isEmpty { exampleChips }
            }
            .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            if stamped {
                StampView(text: "Logged", ink: Color(hex: 0x5FE39A), tilt: -4)
                    .padding(.top, 46)
                    .padding(.trailing, 18)
            }
        }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(lines) { line in
                Text(line.text)
                    .font(.plex(12.5))
                    .foregroundStyle(color(for: line.kind))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Text("duit>")
                    .font(.plex(14, .bold))
                    .foregroundStyle(Theme.terminalYellow)
                TextField(
                    "Type an expense or a question",
                    text: $command,
                    prompt: Text("e.g. bakso 15rb").foregroundStyle(Color(hex: 0x7E81B0))
                )
                .font(.plex(16))
                .foregroundStyle(Theme.terminalText)
                .tint(Theme.terminalYellow)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit(run)
                .onChange(of: command) {
                    if command.count > 80 { command = String(command.prefix(80)) }
                }
                .frame(minHeight: 44)
                if !trimmed.isEmpty {
                    Button(asking ? "Ask" : "Log", action: run)
                        .buttonStyle(.plain)
                        .font(.pixel(14))
                        .foregroundStyle(Theme.terminalBackground)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Theme.terminalYellow)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 2)
        .background(Theme.terminalBackground)
        .overlay { BevelOverlay(topLeft: .black.opacity(0.45), bottomRight: .clear, width: 2) }
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
    }

    private func color(for kind: TermLine.Kind) -> Color {
        switch kind {
        case .dim: Theme.terminalDim
        case .input: Theme.terminalPink
        case .ok: Theme.terminalGreen
        case .error: Theme.terminalError
        }
    }

    // MARK: Preview

    @ViewBuilder
    private func preview(_ p: ParsedEntry) -> some View {
        if p.ok {
            FlowLayout(spacing: 6) {
                RetroPill(text: p.type == .income ? "Income: \(p.title)" : p.title)
                RetroPill(text: CurrencyFormatter.formatRp(p.amount))
                if p.type == .transfer {
                    RetroPill(
                        text: "\(ledger.account(p.fromAccountID)?.name ?? "?") > \(ledger.account(p.toAccountID)?.name ?? "?")",
                        dot: EntryRow.transferColor
                    )
                } else {
                    RetroPill(
                        text: ledger.category(named: p.categoryName, kind: p.type)?.name ?? p.categoryName ?? "Other",
                        dot: (ledger.category(named: p.categoryName, kind: p.type)?.color ?? .gray).color
                    )
                    RetroPill(text: ledger.account(p.accountID)?.name ?? "No wallet")
                }
                RetroPill(text: DateHelpers.formatDayLabel(DateHelpers.addDays(ledger.today, p.dayOffset), today: ledger.today))
            }
            ForEach(Array(notes(for: p).enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.plex(11.5))
                    .foregroundStyle(Theme.ink2)
            }
        } else {
            Text("Add an amount: 18rb, 25.000, goceng, ceban or dua puluh ribu.")
                .font(.plex(11.5))
                .foregroundStyle(Theme.ink2)
        }
    }

    private func notes(for p: ParsedEntry) -> [String] {
        var out = p.notes
        if let b = ledger.battery, b.isPowerSaving, p.type == .expense {
            let share = Int((Double(p.amount) / Double(max(1, b.allowance)) * 100).rounded())
            out.append("That is \(share)% of today’s \(CurrencyFormatter.formatRpCompact(b.allowance)).")
        }
        return out
    }

    private var exampleChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(examples, id: \.self) { example in
                Button(example) { command = example }
                    .buttonStyle(RetroChipStyle())
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Run

    private func run() {
        let text = trimmed
        guard !text.isEmpty else { return }
        var out = [TermLine(kind: .input, text: "duit> \(text)")]

        if TerminalEngine.isQuestion(text) {
            for line in TerminalEngine.answer(text, context: ledger.terminalContext()) {
                out.append(TermLine(kind: .ok, text: line))
            }
            lines = out
            command = ""
            return
        }

        let parsed = SlangParser.parse(text, context: ledger.parseContext())
        guard parsed.ok else {
            out.append(TermLine(kind: .error, text: parsed.type == .transfer && parsed.amount > 0
                ? "Top up needs two wallets, like a bank and an e-wallet."
                : "No amount found. Try 18rb, 25.000, goceng or dua puluh ribu."))
            lines = out
            return
        }
        guard let tx = EntryWriter.insert(parsed, into: context, ledger: ledger) else { return }

        let place: String
        if parsed.type == .transfer {
            place = "\(ledger.account(parsed.fromAccountID)?.name ?? "?") > \(ledger.account(parsed.toAccountID)?.name ?? "?")"
        } else {
            let category = ledger.category(named: parsed.categoryName, kind: parsed.type)?.name ?? parsed.categoryName ?? "Other"
            place = "\(category) · \(ledger.account(parsed.accountID)?.name ?? "No wallet")"
        }
        let day = DateHelpers.formatDayLabel(DateHelpers.addDays(ledger.today, parsed.dayOffset), today: ledger.today)
        out.append(TermLine(kind: .ok, text: "OK  \(parsed.title) · \(CurrencyFormatter.formatRp(parsed.amount)) · \(place) · \(day)"))
        lines = out
        command = ""

        let id = tx.id
        let ctx = context
        toaster.show("Logged \(parsed.title) · \(CurrencyFormatter.formatRp(parsed.amount))") {
            EntryWriter.delete(id: id, in: ctx)
        }
        stamped = true
        Task {
            try? await Task.sleep(for: .milliseconds(950))
            stamped = false
        }
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
                    Text("Nothing logged yet. Type “mie ayam 22rb” in the Terminal, or tap Add.")
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
