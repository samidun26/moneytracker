import SwiftUI
import SwiftData

/// Opens the Balance Check for one wallet.
struct BalanceCheckTarget: Identifiable {
    let id: UUID
}

/// Balance Check — compare what Duit thinks a wallet holds with what the
/// bank or e-wallet app says, then log whatever went unrecorded. After the
/// prototype's "Balance Check" window (design/prototype/Main.dc.html); the
/// guessing rules live in Services/BalanceCheck.swift.
struct BalanceCheckView: View {
    let ledger: Ledger

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster

    @State private var accountID: UUID
    @State private var real = 0

    init(ledger: Ledger, initialAccountID: UUID) {
        self.ledger = ledger
        _accountID = State(initialValue: initialAccountID)
    }

    // MARK: Derived

    private var account: Account? { ledger.account(accountID) }
    private var isCard: Bool { account?.kind == .credit }
    private var name: String { account?.name ?? "Wallet" }

    /// What Duit believes: the balance, or for a card the amount owed.
    private var duitSays: Int {
        let balance = ledger.balances[accountID] ?? 0
        return isCard ? -balance : balance
    }

    private var outcome: BalanceCheck.Outcome {
        BalanceCheck.outcome(isCard: isCard, duitSays: duitSays, appSays: real)
    }

    private var candidates: [BalanceCheck.Candidate] {
        BalanceCheck.candidates(accountID: accountID, kind: account?.kind ?? .cash, entries: ledger.entries)
    }

    private var hint: String {
        switch account?.kind ?? .cash {
        case .ewallet: "Open your \(name) app and type the balance it shows."
        case .cash: "Count the cash in your wallet."
        case .bank: "Type the balance your \(name) app shows."
        case .credit: "Type how much your card app says you owe."
        case .savings: "Type the balance your \(name) account shows."
        }
    }

    /// Where a top-up would come from: cash for a bank, otherwise the bank.
    private var topUpSource: Account? {
        let others = ledger.activeAccounts.filter { $0.id != accountID }
        if account?.kind == .bank { return others.first { $0.kind == .cash } ?? others.first }
        return others.first { $0.kind == .bank } ?? others.first
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar(title: "Balance Check", tint: Theme.titleColors[3], icon: PixelIconData.search) {
                Button { close() } label: {
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
                .accessibilityLabel("Close balance check")
            }

            VStack(spacing: 8) {
                walletPicker
                if real == 0 {
                    Text(hint)
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                lcd
                Text(compareLine)
                    .font(.plex(12))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView { result.frame(maxWidth: .infinity, alignment: .leading) }
                    .scrollIndicators(.hidden)
                    .frame(minHeight: 60)
                Keypad { key in real = applyKey(real, key) }
                footer
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
    }

    // MARK: Pieces

    @ViewBuilder
    private var walletPicker: some View {
        let wallets = ledger.activeAccounts
        if wallets.count <= 4 {
            RetroTabs(items: wallets.map(\.id), label: { id in wallets.first { $0.id == id }?.name ?? "" }, selection: pickerBinding)
        } else {
            Menu {
                ForEach(wallets) { a in Button(a.name) { pickerBinding.wrappedValue = a.id } }
            } label: {
                RetroPopupLabel(text: name)
            }
        }
    }

    private var pickerBinding: Binding<UUID> {
        Binding(get: { accountID }, set: { accountID = $0; real = 0 })
    }

    private var lcd: some View {
        ZStack(alignment: .bottomTrailing) {
            Text("888.888.888").font(.lcd(42)).foregroundStyle(Theme.lcdGhost).accessibilityHidden(true)
            Text("Rp \(CurrencyFormatter.formatNumber(real))")
                .font(.lcd(42))
                .foregroundStyle(Theme.lcdInk)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .bottomTrailing)
        .overlay(alignment: .topLeading) {
            Text(isCard ? "\(name) · amount you owe" : "\(name) · balance in your app")
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
        .accessibilityLabel(isCard ? "Amount you owe" : "Balance in your app")
        .accessibilityValue(CurrencyFormatter.formatRp(real))
    }

    private var compareLine: String {
        let base = (isCard ? "Duit thinks you owe " : "Duit thinks you have ") + CurrencyFormatter.formatRp(duitSays)
        return real > 0 ? base + " · your app says \(CurrencyFormatter.formatRp(real))" : base
    }

    @ViewBuilder
    private var result: some View {
        switch outcome {
        case .waiting:
            EmptyView()
        case .balanced:
            ZStack(alignment: .topLeading) {
                Text("Everything matches. Nice bookkeeping!")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
                StampView(text: "Balanced", ink: Theme.greenInk, tilt: 3, size: .large)
                    .padding(.top, 20)
                    .padding(.leading, 40)
            }
            .frame(minHeight: 80, alignment: .topLeading)
        case .missing(let gap):
            missingView(gap)
        case .extra(let gap):
            extraView(gap)
        }
    }

    private func missingView(_ gap: Int) -> some View {
        let combo = BalanceCheck.bestCombo(candidates, gap: gap)
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(CurrencyFormatter.formatRp(gap)) went out without being logged.")
                .font(.pixel(16))
                .foregroundStyle(Theme.ink)
            if let combo {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Looks like " + combo.map { "\($0.title) \(CurrencyFormatter.formatNumber($0.amount))" }.joined(separator: " + ") + " = exact match.")
                        .font(.plex(13, .semibold))
                        .foregroundStyle(Theme.ink)
                    Button(combo.count > 1 ? "Log all \(combo.count)" : "Log it") { logExpenses(combo.map { ($0.title, $0.amount, $0.categoryName) }) }
                        .buttonStyle(RetroButtonStyle(kind: .primary))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .retroSunk()
            }
            Text("Or tap what it was")
                .font(.plex(11, .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink2)
            FlowLayout(spacing: 6) {
                ForEach(Array(candidates.filter { $0.amount <= gap }.enumerated()), id: \.offset) { _, c in
                    Button { logExpenses([(c.title, c.amount, c.categoryName)]) } label: {
                        HStack(spacing: 7) {
                            ColorDot(color: (ledger.category(named: c.categoryName, kind: .expense)?.color ?? .gray).color)
                            Text("\(c.title) · \(CurrencyFormatter.formatNumber(c.amount))")
                        }
                    }
                    .buttonStyle(RetroChipStyle())
                    .accessibilityLabel("Log \(c.title) \(CurrencyFormatter.formatRp(c.amount))")
                }
                Button { logExpenses([("Unlogged spending", gap, "Other")]) } label: {
                    Text("Rest as Other · \(CurrencyFormatter.formatRpCompact(gap))")
                }
                .buttonStyle(RetroChipStyle())
            }
        }
    }

    private func extraView(_ gap: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(CurrencyFormatter.formatRp(gap)) more than Duit expected.")
                .font(.pixel(16))
                .foregroundStyle(Theme.ink)
            FlowLayout(spacing: 10) {
                if let source = topUpSource {
                    Button("Top up from \(source.name)") { logTopUp(gap, from: source) }
                        .buttonStyle(RetroButtonStyle(small: true))
                }
                Button("Log as income") { logIncome(gap) }
                    .buttonStyle(RetroButtonStyle(small: true))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(footerText)
                .font(.plex(12))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") { close() }
                .buttonStyle(RetroButtonStyle(kind: .primary))
        }
        .padding(.trailing, 4)
    }

    private var footerText: String {
        switch outcome {
        case .waiting: "Type the balance with the keypad."
        case .balanced: "All good. Duit matches your app."
        case .missing, .extra: "Tap a guess, or log the rest."
        }
    }

    // MARK: Actions

    /// Closing after typing a balance counts as having checked this wallet.
    private func close() {
        if real > 0, let account {
            account.lastCheckedAt = ledger.today
            try? context.save()
        }
        dismiss()
    }

    private func logExpenses(_ items: [(title: String, amount: Int, category: String?)]) {
        guard let account else { return }
        var created: [UUID] = []
        for item in items {
            let tx = Transaction(
                type: .expense, amount: item.amount,
                category: ledger.category(named: item.category, kind: .expense),
                note: item.title, date: ledger.today, account: account
            )
            context.insert(tx)
            created.append(tx.id)
        }
        try? context.save()
        announce(created, text: items.count == 1 ? "Logged \(items[0].title)" : "Logged \(items.count) items")
    }

    private func logTopUp(_ amount: Int, from source: Account) {
        guard let account else { return }
        let tx = Transaction(type: .transfer, amount: amount, note: "Top up \(account.name)", date: ledger.today, account: source, toAccount: account)
        context.insert(tx)
        try? context.save()
        announce([tx.id], text: "Logged top up")
    }

    private func logIncome(_ amount: Int) {
        guard let account else { return }
        let tx = Transaction(
            type: .income, amount: amount,
            category: ledger.category(named: "Other", kind: .income),
            note: "Unlogged income", date: ledger.today, account: account
        )
        context.insert(tx)
        try? context.save()
        announce([tx.id], text: "Logged income")
    }

    private func announce(_ ids: [UUID], text: String) {
        let ctx = context
        toaster.show(text) {
            for id in ids { EntryWriter.delete(id: id, in: ctx) }
        }
    }
}
