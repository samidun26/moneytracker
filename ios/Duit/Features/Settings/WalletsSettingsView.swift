import SwiftUI
import SwiftData

/// Settings → Wallets: every wallet with its balance, tap one to rename it,
/// change its type or starting balance, archive it or (if it has no history)
/// delete it, and a button to add another.
struct WalletsSettingsView: View {
    let ledger: Ledger

    @Environment(\.dismiss) private var dismiss
    @State private var target: WalletTarget?

    enum WalletTarget: Identifiable {
        case new
        case existing(UUID)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let id): id.uuidString
            }
        }
    }

    private var active: [Account] { ledger.accounts.filter { !$0.archived } }
    private var archived: [Account] { ledger.accounts.filter(\.archived) }

    var body: some View {
        RetroSheet(title: "Wallets", tint: Theme.titleColors[1], icon: PixelIconData.cash, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cash, bank accounts, e-wallets and cards. Duit works out each balance from what you log.")
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)

                    VStack(spacing: 0) {
                        ForEach(Array(active.enumerated()), id: \.element.id) { index, account in
                            if index > 0 { DottedDivider() }
                            row(account)
                        }
                    }
                    .retroSunk()

                    Button("Add a wallet") { target = .new }
                        .buttonStyle(RetroButtonStyle(kind: .primary))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)

                    if !archived.isEmpty {
                        Text("Archived")
                            .font(.plex(11, .semibold))
                            .tracking(0.9)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.ink2)
                            .padding(.top, 6)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(Array(archived.enumerated()), id: \.element.id) { index, account in
                                if index > 0 { DottedDivider() }
                                row(account)
                            }
                        }
                        .retroSunk()
                    }
                }
                .padding(14)
            }
        }
        .sheet(item: $target) { target in
            switch target {
            case .new: WalletEditorView(ledger: ledger, accountID: nil)
            case .existing(let id): WalletEditorView(ledger: ledger, accountID: id)
            }
        }
    }

    private func row(_ account: Account) -> some View {
        let balance = ledger.balances[account.id] ?? 0
        let owed = account.kind == .credit
        return Button { target = .existing(account.id) } label: {
            HStack(spacing: 10) {
                PixelTile(rects: account.kind.icon, color: account.color.color, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.name)
                        .font(.plex(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(account.archived ? "\(account.kind.label) · archived" : account.kind.label)
                        .font(.plex(11.5))
                        .foregroundStyle(Theme.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(owed ? "owe \(CurrencyFormatter.formatRpCompact(-balance))" : CurrencyFormatter.formatRpCompact(balance))
                    .font(.plex(13, .semibold))
                    .foregroundStyle(balance < 0 && !owed ? Theme.negative : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel("\(account.name), \(account.kind.label)\(account.archived ? ", archived" : "")")
        .accessibilityValue(owed ? "You owe \(CurrencyFormatter.formatRp(-balance))" : CurrencyFormatter.formatRp(balance))
        .accessibilityHint("Edit this wallet")
    }
}

// MARK: - Editor

struct WalletEditorView: View {
    let ledger: Ledger
    /// nil = a new wallet.
    let accountID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster

    @State private var name: String
    @State private var kind: AccountKind
    @State private var opening: Int
    @State private var openingEdited = false
    @State private var editingOpening = false
    @State private var alert: RetroAlertContent?

    init(ledger: Ledger, accountID: UUID?) {
        self.ledger = ledger
        self.accountID = accountID
        let account = ledger.account(accountID)
        _name = State(initialValue: account?.name ?? "")
        _kind = State(initialValue: account?.kind ?? .bank)
        _opening = State(initialValue: account.map { WalletRules.enteredOpening(stored: $0.openingBalance, kind: $0.kind) } ?? 0)
    }

    private var account: Account? { ledger.account(accountID) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var canDelete: Bool {
        guard let account else { return false }
        let ruleAccounts = Set(ledger.rules.flatMap { [$0.account?.id, $0.toAccount?.id] }.compactMap { $0 })
        return WalletRules.canDelete(account.id, entries: ledger.entries, ruleAccountIDs: ruleAccounts)
    }

    var body: some View {
        RetroSheet(
            title: account == nil ? "New wallet" : "Edit wallet",
            tint: Theme.titleColors[1],
            icon: PixelIconData.cash,
            closeLabel: "Close without saving",
            onClose: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RetroTextField(caption: "Name", placeholder: "BCA, GoPay, Cash…", text: $name)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.plex(11, .semibold))
                            .tracking(0.9)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.ink2)
                        Menu {
                            ForEach(AccountKind.allCases, id: \.self) { option in
                                Button(option.label) { kind = option }
                            }
                        } label: {
                            RetroPopupLabel(text: kind.label)
                        }
                        .accessibilityLabel("Type")
                        .accessibilityValue(kind.label)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        RetroValueRow(
                            label: kind == .credit ? "Amount you owe at the start" : "Starting balance",
                            value: CurrencyFormatter.formatRp(opening),
                            accessibilityHint: "Opens the keypad"
                        ) { editingOpening = true }
                        .retroSunk()
                        Text("Counted before any transaction you log. To match your real app later, use Balance Check from Activity.")
                            .font(.plex(12))
                            .foregroundStyle(Theme.ink2)
                    }

                    if let account {
                        manageButtons(account)
                    }

                    HStack(spacing: 12) {
                        Spacer()
                        Button("Cancel") { dismiss() }
                            .buttonStyle(RetroButtonStyle())
                        Button("Save", action: save)
                            .buttonStyle(RetroButtonStyle(kind: .primary))
                            .disabled(trimmedName.isEmpty)
                            .opacity(trimmedName.isEmpty ? 0.5 : 1)
                    }
                    .padding(.trailing, 4)
                }
                .padding(14)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $editingOpening) {
            AmountEditorView(
                title: "Starting balance",
                caption: kind == .credit ? "Amount you owe" : "Starting balance",
                initial: opening
            ) { value in
                opening = value
                openingEdited = true
            }
        }
        .retroAlert($alert)
    }

    @ViewBuilder
    private func manageButtons(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button(account.archived ? "Restore" : "Archive") { toggleArchive(account) }
                    .buttonStyle(RetroButtonStyle(small: true))
                if canDelete {
                    Button("Delete") { askDelete(account) }
                        .buttonStyle(RetroButtonStyle(kind: .danger, small: true))
                }
            }
            Text(canDelete
                ? "Archiving hides a wallet but keeps its history. Delete removes it for good."
                : "This wallet has history, so it can be archived but not deleted. Archived wallets stay in your totals' history.")
                .font(.plex(12))
                .foregroundStyle(Theme.ink2)
        }
    }

    // MARK: Actions

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if let account {
            let kindChanged = account.kind != kind
            account.name = trimmedName
            account.kind = kind
            if kindChanged { account.color = kind.color }
            if openingEdited || kindChanged {
                // Re-store the number in the new kind's convention (owed vs held).
                account.openingBalance = WalletRules.storedOpening(entered: opening, kind: kind)
            }
        } else {
            let next = (ledger.accounts.map(\.order).max() ?? -1) + 1
            context.insert(Account(
                name: trimmedName,
                kind: kind,
                openingBalance: WalletRules.storedOpening(entered: opening, kind: kind),
                order: next
            ))
        }
        try? context.save()
        toaster.show("Saved \(trimmedName)")
        dismiss()
    }

    private func toggleArchive(_ account: Account) {
        if !account.archived, ledger.activeAccounts.count <= 1 {
            alert = RetroAlertContent(
                title: "Keep one wallet",
                message: "Duit needs at least one active wallet to log money in. Add another first, then archive this one.",
                icon: PixelIconData.caution
            )
            return
        }
        account.archived.toggle()
        try? context.save()
        toaster.show(account.archived ? "Archived \(account.name)" : "Restored \(account.name)")
        dismiss()
    }

    private func askDelete(_ account: Account) {
        if !account.archived, ledger.activeAccounts.count <= 1 {
            alert = RetroAlertContent(
                title: "Keep one wallet",
                message: "Duit needs at least one active wallet to log money in. Add another first, then delete this one.",
                icon: PixelIconData.caution
            )
            return
        }
        let name = account.name
        let ctx = context
        let id = account.id
        let toaster = toaster
        let close = dismiss
        alert = RetroAlertContent(
            title: "Delete \(name)?",
            message: "It has no transactions, so nothing else changes. This can't be undone.",
            icon: PixelIconData.caution,
            confirmLabel: "Delete",
            action: {
                var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
                descriptor.fetchLimit = 1
                if let doomed = try? ctx.fetch(descriptor).first {
                    ctx.delete(doomed)
                    try? ctx.save()
                }
                toaster.show("Deleted \(name)")
                close()
            }
        )
    }
}
