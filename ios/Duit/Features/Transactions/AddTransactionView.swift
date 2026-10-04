import SwiftUI
import SwiftData

/// What the composer was opened for.
enum ComposerRequest: Identifiable {
    case add(TransactionType)
    case edit(UUID)

    var id: String {
        switch self {
        case .add(let type): "add-\(type.rawValue)"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

/// Add or edit an expense, income or transfer — the prototype's composer
/// window (design/prototype/Main.dc.html): accent title bar, folder tabs, LCD
/// amount, note with suggestions, tile grid, wallet and day menus, keypad,
/// and a status line beside Save. Ports src/features/transactions/Composer.tsx.
struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster

    let ledger: Ledger
    /// nil = adding; set = editing an existing transaction.
    let editing: Transaction?

    @State private var type: TransactionType
    @State private var amount: Int
    @State private var category: Category?
    @State private var account: Account?
    @State private var toAccount: Account?
    @State private var date: Date
    @State private var note: String
    @State private var error: String?
    @State private var stamping = false
    @State private var pickingDate = false

    init(request: ComposerRequest, ledger: Ledger) {
        self.ledger = ledger
        var tx: Transaction?
        var startType = TransactionType.expense
        switch request {
        case .edit(let id): tx = ledger.transaction(id: id)
        case .add(let t): startType = t
        }
        editing = tx
        _type = State(initialValue: tx?.type ?? startType)
        _amount = State(initialValue: tx?.amount ?? 0)
        _category = State(initialValue: tx?.category)
        _date = State(initialValue: tx.map { DateHelpers.startOfDay($0.date) } ?? ledger.today)
        _note = State(initialValue: tx?.note ?? "")
        let start = AddTransactionView.accounts(for: tx?.type ?? startType, ledger: ledger)
        _account = State(initialValue: tx?.account ?? start.0)
        _toAccount = State(initialValue: tx?.toAccount ?? start.1)
    }

    /// The wallet(s) to start with for a kind of entry.
    private static func accounts(for type: TransactionType, ledger: Ledger) -> (Account?, Account?) {
        let refs = ledger.accountRefs
        switch type {
        case .expense:
            return (ledger.account(AccountDefaults.expense(refs, last: AccountDefaults.read(Prefs.lastExpenseAccount))), nil)
        case .income:
            return (ledger.account(AccountDefaults.income(refs, last: AccountDefaults.read(Prefs.lastIncomeAccount))), nil)
        case .transfer:
            let pair = AccountDefaults.transferPair(refs)
            return (ledger.account(pair.from), ledger.account(pair.to))
        }
    }

    // MARK: Derived

    private var windowTitle: String {
        let kind = type == .income ? "income" : (type == .transfer ? "transfer" : "expense")
        return editing == nil ? "New \(kind)" : "Edit \(kind)"
    }

    private var kindCategories: [Category] { ledger.categories(of: type) }

    private var maxDate: Date { DateHelpers.addDays(ledger.today, 366) }

    /// Past titles of this kind to offer as shortcuts — never bare category names.
    private var suggestions: [Entry] {
        var seen = Set<String>()
        var pool: [Entry] = []
        for e in ledger.entries where e.type == type && !e.title.isEmpty && e.title != e.categoryName {
            if seen.insert(e.title.lowercased()).inserted { pool.append(e) }
        }
        let query = note.trimmingCharacters(in: .whitespaces).lowercased()
        return pool
            .filter { query.isEmpty || ($0.title.lowercased().contains(query) && $0.title.lowercased() != query) }
            .prefix(8)
            .map { $0 }
    }

    private var statusLine: (text: String, isError: Bool) {
        if let error { return (error, true) }
        if amount == 0 { return ("Type the amount, then pick a category.", false) }
        if type != .transfer && category == nil { return ("Now pick a category.", false) }
        if type == .expense, editing == nil, let b = ledger.battery, b.isPowerSaving {
            let share = Int((Double(amount) / Double(max(1, b.allowance)) * 100).rounded())
            return ("That’s \(share)% of today’s \(CurrencyFormatter.formatRpCompact(b.allowance)).", false)
        }
        return (editing == nil ? "Tap Save when you’re done." : "Change anything, then Save.", false)
    }

    private var dayLabel: String { DateHelpers.formatDayLabel(date, today: ledger.today) }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar(
                title: windowTitle,
                tint: Theme.accent,
                ink: Theme.accentInk,
                icon: editing == nil ? PixelIconData.plus : PixelIconData.activity
            ) {
                closeBox
            }

            VStack(spacing: 8) {
                if editing == nil {
                    RetroTabs(
                        items: [TransactionType.expense, .income, .transfer],
                        label: { $0 == .income ? "Income" : ($0 == .transfer ? "Transfer" : "Expense") },
                        selection: $type
                    )
                    .onChange(of: type) { switchedType() }
                }

                amountDisplay
                noteField
                if !suggestions.isEmpty { suggestionChips }
                if type == .transfer { transferPickers } else { categoryGrid }
                optionsRow

                Keypad { key in
                    amount = applyKey(amount, key)
                    error = nil
                }

                footer
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
        .overlay {
            if stamping {
                StampView(text: "Saved", ink: Theme.redInk, tilt: -12, size: .large)
            }
        }
        .allowsHitTesting(!stamping)
        .sheet(isPresented: $pickingDate) { datePickerSheet }
    }

    // MARK: Pieces

    private var closeBox: some View {
        Button { dismiss() } label: {
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
        .accessibilityLabel("Close without saving")
    }

    private var amountDisplay: some View {
        ZStack(alignment: .bottomTrailing) {
            Text("888.888.888")
                .font(.lcd(42))
                .foregroundStyle(Theme.lcdGhost)
                .accessibilityHidden(true)
            Text("Rp \(CurrencyFormatter.formatNumber(amount))")
                .font(.lcd(42))
                .foregroundStyle(Theme.lcdInk)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .bottomTrailing)
        .overlay(alignment: .topLeading) {
            Text(captionText)
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
        .accessibilityLabel("Amount")
        .accessibilityValue(CurrencyFormatter.formatRp(amount))
    }

    /// "Expense · Mie Ayam" — the kind, then the title as you type it.
    private var captionText: String {
        let kind = type == .income ? "Income" : (type == .transfer ? "Transfer" : "Expense")
        let title = note.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? kind : "\(kind) · \(title)"
    }

    private var noteField: some View {
        HStack(spacing: 8) {
            Text("Title")
                .font(.pixel(12))
                .foregroundStyle(Theme.ink2)
            TextField(
                "Title",
                text: $note,
                prompt: Text(type == .income ? "e.g. Salary September" : (type == .transfer ? "e.g. Top up GoPay" : "e.g. Mie Ayam"))
                    .foregroundStyle(Theme.ink2)
            )
            .font(.plex(16, .semibold))
            .foregroundStyle(Theme.ink)
            .autocorrectionDisabled() // slang like "goceng" shouldn't be "fixed"
            .submitLabel(.done)
            .onChange(of: note) {
                if note.count > 40 { note = String(note.prefix(40)) }
                error = nil
            }
            if !note.isEmpty {
                Button { note = "" } label: {
                    Text("x")
                        .font(.pixel(11))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 18, height: 18)
                        .background(Theme.face)
                        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear title")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .frame(minHeight: 44)
        .retroSunk()
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                Text(note.trimmingCharacters(in: .whitespaces).isEmpty ? "Recent" : "Matches")
                    .font(.plex(10.5, .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.ink2)
                ForEach(suggestions) { s in
                    Button {
                        useSuggestion(s)
                    } label: {
                        HStack(spacing: 7) {
                            ColorDot(color: (s.categoryColor ?? .gray).color)
                            Text(s.title)
                        }
                    }
                    .buttonStyle(RetroChipStyle())
                    .accessibilityLabel("Use title \(s.title)")
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -12)
    }

    /// Tiles in whole rows that scroll sideways — never a half-cut row.
    private var categoryGrid: some View {
        GeometryReader { geo in
            let rowHeight: CGFloat = 80
            let rows = max(1, Int((geo.size.height + 4) / (rowHeight + 4)))
            let columnWidth = max(68, geo.size.width * 0.22)
            ScrollView(.horizontal) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(rowHeight), spacing: 4), count: rows), spacing: 4) {
                    ForEach(kindCategories) { c in
                        categoryCell(c).frame(width: columnWidth)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicatorsFlash(onAppear: true)
        }
        .frame(minHeight: 168)
    }

    private func categoryCell(_ c: Category) -> some View {
        let selected = category?.id == c.id
        return Button {
            category = c
            error = nil
        } label: {
            VStack(spacing: 3) {
                // Selected: a 2pt paper gap, then a 3pt accent ring.
                IconBadge(icon: c.icon, color: c.color, size: 40)
                    .padding(2)
                    .background(Theme.paper)
                    .padding(3)
                    .background(selected ? Theme.accent : Color.clear)
                Text(c.name)
                    .font(.plex(10.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .foregroundStyle(selected ? Theme.accentInk : Theme.ink)
                    .background(selected ? Theme.accent : Color.clear)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(c.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var transferPickers: some View {
        VStack(alignment: .leading, spacing: 12) {
            accountMenu(prefix: "From", binding: $account)
            accountMenu(prefix: "To", binding: $toAccount)
            Text("Transfers move money between your own wallets, so they don’t count as spending.")
                .font(.plex(12.5))
                .foregroundStyle(Theme.ink2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .padding(.vertical, 6)
    }

    private func accountMenu(prefix: String, binding: Binding<Account?>) -> some View {
        Menu {
            ForEach(ledger.activeAccounts) { a in
                Button {
                    binding.wrappedValue = a
                    error = nil
                } label: {
                    if binding.wrappedValue?.id == a.id {
                        Label(a.name, systemImage: "checkmark")
                    } else {
                        Text(a.name)
                    }
                }
            }
        } label: {
            RetroPopupLabel(text: "\(prefix): \(binding.wrappedValue?.name ?? "Choose")")
        }
        .accessibilityLabel("\(prefix) wallet")
    }

    /// The wallet and the day, as two menus side by side (the prototype's `.pops`).
    private var optionsRow: some View {
        HStack(spacing: 10) {
            if type != .transfer {
                accountMenu(prefix: type == .income ? "Into" : "Via", binding: $account)
            }
            Menu {
                Button("Today") { date = ledger.today }
                Button("Yesterday") { date = DateHelpers.addDays(ledger.today, -1) }
                Button("Pick a date…") { pickingDate = true }
            } label: {
                RetroPopupLabel(text: dayLabel)
            }
            .accessibilityLabel("Day, \(dayLabel)")
        }
    }

    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            RetroTitleBar(title: "Pick a day", tint: Theme.titleColors[3], icon: PixelIconData.activity) {
                Button { pickingDate = false } label: {
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
                .accessibilityLabel("Close")
            }
            DatePicker("Day", selection: $date, in: ...maxDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.accent)
                .padding(12)
            Button("Done") { pickingDate = false }
                .buttonStyle(RetroButtonStyle(kind: .primary))
                .padding(.bottom, 16)
            Spacer(minLength: 0)
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
        .presentationDetents([.medium, .large])
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(statusLine.text)
                .font(.plex(statusLine.isError ? 12 : 12, statusLine.isError ? .bold : .regular))
                .foregroundStyle(statusLine.isError ? Theme.negative : Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if editing != nil {
                Button("Delete") { delete() }
                    .buttonStyle(RetroButtonStyle(kind: .danger))
                    .accessibilityLabel("Delete this transaction")
            }
            Button("Save") { save() }
                .buttonStyle(RetroButtonStyle(kind: .primary))
        }
        .padding(.trailing, 4)
    }

    // MARK: Actions

    /// A new entry's wallet follows its kind (an e-wallet for spending, a bank for income).
    private func switchedType() {
        if let c = category, c.kind != type { category = nil }
        let start = AddTransactionView.accounts(for: type, ledger: ledger)
        account = start.0
        toAccount = start.1
        error = nil
    }

    private func useSuggestion(_ s: Entry) {
        note = s.title
        if type != .transfer, let id = s.categoryID, let match = ledger.categories.first(where: { $0.id == id }) {
            category = match
        }
        if let id = s.accountID, let match = ledger.account(id), !match.archived { account = match }
        if type == .transfer, let id = s.toAccountID, let match = ledger.account(id), !match.archived { toAccount = match }
        error = nil
    }

    private func save() {
        guard !stamping else { return }
        if amount <= 0 { return fail("Type an amount on the keypad first.") }
        if type != .transfer && category == nil { return fail("Pick a category.") }
        if account == nil { return fail("Pick a wallet.") }
        if type == .transfer && (toAccount == nil || toAccount?.id == account?.id) { return fail("Pick two different wallets.") }

        let title = note.trimmingCharacters(in: .whitespaces)
        let name = title.isEmpty ? (type == .transfer ? "Transfer" : (category?.name ?? "Entry")) : title
        let day = DateHelpers.startOfDay(date)

        if let editing {
            editing.type = type
            editing.amount = amount
            editing.category = type == .transfer ? nil : category
            editing.note = title
            editing.date = day
            editing.account = account
            editing.toAccount = type == .transfer ? toAccount : nil
            editing.updatedAt = .now
            try? context.save()
            toaster.show("Updated \(name)")
        } else {
            let tx = Transaction(
                type: type, amount: amount,
                category: type == .transfer ? nil : category,
                note: title, date: day,
                account: account, toAccount: type == .transfer ? toAccount : nil
            )
            context.insert(tx)
            try? context.save()
            let id = tx.id
            let ctx = context
            toaster.show("Saved \(name) · \(CurrencyFormatter.formatRp(amount))") {
                EntryWriter.delete(id: id, in: ctx)
            }
        }
        switch type {
        case .expense: AccountDefaults.remember(account?.id, key: Prefs.lastExpenseAccount)
        case .income: AccountDefaults.remember(account?.id, key: Prefs.lastIncomeAccount)
        case .transfer: break
        }

        stamping = true
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        }
    }

    private func fail(_ message: String) {
        error = message
    }

    private func delete() {
        guard let editing else { return }
        let snapshot = EntryWriter.Snapshot(editing)
        let name = editing.note.isEmpty ? (editing.category?.name ?? "entry") : editing.note
        let value = editing.amount
        context.delete(editing)
        try? context.save()
        let ctx = context
        toaster.show("Deleted \(name) · \(CurrencyFormatter.formatRp(value))") {
            snapshot.restore(into: ctx)
        }
        dismiss()
    }
}
