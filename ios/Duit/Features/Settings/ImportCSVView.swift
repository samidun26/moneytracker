import SwiftUI

/// A CSV the user picked, already read, waiting for their OK.
struct PendingImport: Identifiable {
    let id = UUID()
    let fileName: String
    let file: ImportFile
}

/// The preview after picking a file in Settings → Sync & data → Import CSV:
/// what Duit understood, how many rows are new, which are already logged, and
/// (for a bank statement) which wallet they belong to. Nothing is written
/// until "Add".
struct ImportCSVView: View {
    let ledger: Ledger
    let pending: PendingImport

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster

    /// The wallet for rows that name none: every bank-statement row.
    @State private var walletID: UUID?
    /// Only asked when the file doesn't say which way its amounts go.
    @State private var positiveIsIncome = true

    init(ledger: Ledger, pending: PendingImport) {
        self.ledger = ledger
        self.pending = pending
        _walletID = State(initialValue: AccountDefaults.income(ledger.accountRefs, last: nil))
    }

    private var isStatement: Bool { pending.file.kind == .statement }
    private var needsWallet: Bool {
        isStatement || pending.file.rows.contains { ($0.accountName ?? "").isEmpty }
    }

    private func makePlan() -> ImportPlan {
        ImportPlan.make(
            file: pending.file,
            existing: ledger.entries,
            wallets: ledger.accountRefs,
            defaultWallet: ledger.account(walletID)?.name,
            positiveIsIncome: positiveIsIncome
        )
    }

    var body: some View {
        let plan = makePlan()
        RetroSheet(title: "Import CSV", tint: Theme.titleColors[2], icon: PixelIconData.box, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    summary(plan)
                    if needsWallet { walletPicker }
                    if pending.file.directionIsGuessed { directionPicker }
                    notes(plan)
                    if !plan.items.isEmpty { preview(plan) }
                    buttons(plan)
                }
                .padding(14)
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(isStatement ? "Bank statement" : "Duit export")
                .font(.pixel(14))
                .foregroundStyle(Theme.ink)
            Text(pending.fileName)
                .font(.plex(12))
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .accessibilityElement(children: .combine)
    }

    private func summary(_ plan: ImportPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                LCDStatBox(caption: "To add", value: "\(plan.items.count)")
                LCDStatBox(caption: "Already in Duit", value: "\(plan.duplicates)")
                if !plan.problems.isEmpty {
                    LCDStatBox(caption: "Skipped", value: "\(plan.problems.count)")
                }
            }
            if !plan.items.isEmpty {
                Text("Spending \(CurrencyFormatter.formatRp(plan.expenseTotal)) · Income \(CurrencyFormatter.formatRp(plan.incomeTotal))")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
            }
        }
    }

    private var walletPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            caption(isStatement ? "Add them to" : "Rows without a wallet go to")
            Menu {
                ForEach(ledger.activeAccounts, id: \.id) { account in
                    Button(account.name) { walletID = account.id }
                }
            } label: {
                RetroPopupLabel(text: ledger.account(walletID)?.name ?? "Choose a wallet")
            }
            .accessibilityLabel("Wallet")
            .accessibilityValue(ledger.account(walletID)?.name ?? "None chosen")
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption("In this file, plain numbers are")
            RetroSegmented(items: [true, false], label: { $0 ? "Money in" : "Money out" }, selection: $positiveIsIncome)
            Text("This file has no minus signs, DB/CR marks or type column, so Duit can't tell. Check the first rows below.")
                .font(.plex(12))
                .foregroundStyle(Theme.ink2)
        }
    }

    @ViewBuilder
    private func notes(_ plan: ImportPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !plan.newWallets.isEmpty {
                note("New wallet\(plan.newWallets.count == 1 ? "" : "s") will be created: \(plan.newWallets.joined(separator: ", ")). They start at Rp 0; set a starting balance in Settings → Wallets, or use Balance Check.")
            }
            if plan.items.isEmpty && plan.duplicates > 0 {
                note("Everything in this file is already in Duit.")
            } else if plan.duplicates > 0 {
                note(isStatement
                    ? "Rows that match something you already logged (same day, amount and wallet) are skipped."
                    : "Transactions that are already in Duit are skipped.")
            }
            if isStatement && !plan.items.isEmpty {
                note("Categories come from titles you've used before; everything else goes to Other. Edit any row afterwards.")
            }
            ForEach(Array(plan.problems.prefix(3).enumerated()), id: \.offset) { _, problem in
                note("Skipped row \(problem.row): \(problem.reason)")
            }
            if plan.problems.count > 3 {
                note("…and \(plan.problems.count - 3) more skipped rows.")
            }
        }
    }

    private func preview(_ plan: ImportPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            caption("First rows")
            VStack(spacing: 0) {
                ForEach(Array(plan.items.prefix(6).enumerated()), id: \.offset) { index, item in
                    if index > 0 { DottedDivider() }
                    previewRow(item)
                }
                if plan.items.count > 6 {
                    DottedDivider()
                    Text("…and \(plan.items.count - 6) more")
                        .font(.plex(12))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }
            .retroSunk()
        }
    }

    private func previewRow(_ item: ImportPlan.Item) -> some View {
        let row = item.row
        let income = row.type == .income
        let transfer = row.type == .transfer
        let title = row.title.isEmpty ? (item.categoryName ?? (transfer ? "Transfer" : "Untitled")) : row.title
        let detail = [DateHelpers.formatShortDate(row.date), item.accountName, item.categoryName]
            .compactMap { $0 }
            .joined(separator: " · ")
        let amount = (income ? "+" : transfer ? "" : "-") + CurrencyFormatter.formatRp(row.amount)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.plex(13.5, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.plex(11.5))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(amount)
                .font(.plex(13, .semibold))
                .foregroundStyle(income ? Theme.greenInk : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func buttons(_ plan: ImportPlan) -> some View {
        HStack(spacing: 12) {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(RetroButtonStyle())
            Button(plan.items.isEmpty ? "Nothing new" : "Add \(plan.items.count)") { commit(plan) }
                .buttonStyle(RetroButtonStyle(kind: .primary))
                .disabled(plan.items.isEmpty)
                .opacity(plan.items.isEmpty ? 0.5 : 1)
        }
        .padding(.trailing, 4)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.plex(11, .semibold))
            .tracking(0.9)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink2)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.plex(12))
            .foregroundStyle(Theme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Action

    private func commit(_ plan: ImportPlan) {
        let committed = ImportWriter.commit(plan, into: context)
        let ctx = context
        let ids = committed.ids
        var text = "Added \(ids.count) transaction\(ids.count == 1 ? "" : "s")"
        if !committed.walletsCreated.isEmpty {
            text += " · \(committed.walletsCreated.count) new wallet\(committed.walletsCreated.count == 1 ? "" : "s")"
        }
        toaster.show(text, undo: { ImportWriter.remove(ids: ids, from: ctx) })
        dismiss()
    }
}
