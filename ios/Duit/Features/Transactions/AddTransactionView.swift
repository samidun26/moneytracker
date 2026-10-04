import SwiftUI
import SwiftData

/// Add/edit a transaction — ports src/features/transactions/Composer.tsx,
/// minus the account/transfer picker (no Accounts in the MVP yet; every
/// transaction is against a single implicit balance until that slice
/// lands — see docs/IOS_NATIVE_PLAN.md §3).
///
/// Styled after the retro prototype's composer window (design/prototype):
/// accent title bar with a close box, folder tabs, LCD amount, sunken note
/// field, tile category grid, LCD-font keypad, and a ringed Save button.
struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.order) private var categories: [Category]

    /// nil = adding a new transaction; set = editing an existing one.
    var editing: Transaction?

    @State private var type: TransactionType
    @State private var amount: Int
    @State private var category: Category?
    @State private var date: Date
    @State private var note: String
    @State private var showProblem = false

    init(editing: Transaction? = nil) {
        self.editing = editing
        _type = State(initialValue: editing?.type ?? .expense)
        _amount = State(initialValue: editing?.amount ?? 0)
        _category = State(initialValue: editing?.category)
        _date = State(initialValue: editing.map { DateHelpers.startOfDay($0.date) } ?? DateHelpers.today())
        _note = State(initialValue: editing?.note ?? "")
    }

    private var kindCategories: [Category] {
        categories.filter { $0.kind == type }
    }

    private var problem: String? {
        if amount <= 0 { return "Enter an amount" }
        if category == nil { return "Pick a category" }
        return nil
    }

    /// Matches the web composer's date input `max` (src/features/transactions/Composer.tsx: `addDays(today, 366)`).
    private var maxDate: Date {
        Calendar.current.date(byAdding: .day, value: 366, to: DateHelpers.today()) ?? DateHelpers.today()
    }

    private var windowTitle: String {
        editing == nil ? (type == .income ? "New income" : "New expense") : "Edit \(type.rawValue)"
    }

    var body: some View {
        VStack(spacing: 0) {
            RetroTitleBar(title: windowTitle, tint: Theme.accent, ink: Theme.accentInk) {
                closeBox
            }

            VStack(spacing: 10) {
                RetroTabs(items: [TransactionType.expense, .income], label: { $0 == .income ? "Income" : "Expense" }, selection: $type)
                    .onChange(of: type) {
                        if let category, category.kind != type { self.category = nil }
                    }

                amountDisplay
                noteField
                categoryGrid
                dateRow

                Keypad { key in
                    amount = applyKey(amount, key)
                }

                footer
            }
            .padding(12)
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
    }

    // MARK: Pieces

    /// The prototype's "x" box in the title bar. The visible box is small but
    /// the tap target is the full 44pt.
    private var closeBox: some View {
        Button {
            dismiss()
        } label: {
            Text("x")
                .font(.pixel(14))
                .foregroundStyle(Theme.ink)
                .frame(width: 22, height: 22)
                .background(Theme.face)
                .overlay { BevelOverlay(topLeft: Theme.hi, bottomRight: Theme.lo) }
                .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close without saving")
    }

    /// Green LCD with unlit "888" ghost digits behind the amount.
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
            Text(type == .income ? "Income" : "Expense")
                .font(.plex(11, .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.lcdInk)
                .padding(.leading, 10)
                .padding(.top, 7)
                .accessibilityHidden(true)
        }
        .background(Theme.lcd)
        .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount")
        .accessibilityValue(CurrencyFormatter.formatRp(amount))
    }

    private var noteField: some View {
        HStack(spacing: 8) {
            Text("Note")
                .font(.plex(10.5, .bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink2)
            TextField(
                "Note",
                text: $note,
                prompt: Text("Add a note (e.g. Kopi Kenangan)").foregroundStyle(Theme.ink2)
            )
            .font(.plex(16, .semibold))
            .foregroundStyle(Theme.ink)
            .autocorrectionDisabled() // slang like "goceng" shouldn't be "fixed"
            .submitLabel(.done)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .retroSunk()
    }

    /// 4-column tile grid. Scrolls when the screen is too short for every
    /// category; the scroll bar flashes on appear so that's discoverable.
    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 2) {
                ForEach(kindCategories) { c in
                    categoryCell(c)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollIndicatorsFlash(onAppear: true)
        .frame(minHeight: 140)
    }

    private func categoryCell(_ c: Category) -> some View {
        let selected = category == c
        return Button {
            category = c
        } label: {
            VStack(spacing: 4) {
                // Selected: a 2pt paper gap, then a 3pt accent ring.
                IconBadge(icon: c.icon, color: c.color, size: 44)
                    .padding(2)
                    .background(Theme.paper)
                    .padding(3)
                    .background(selected ? Theme.accent : Color.clear)
                Text(c.name)
                    .font(.plex(10.5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .foregroundStyle(selected ? Theme.accentInk : Theme.ink)
                    .background(selected ? Theme.accent : Color.clear)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .top)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(c.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var dateRow: some View {
        HStack(spacing: 8) {
            DatePicker(
                "Date",
                selection: $date,
                in: ...maxDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .tint(Theme.accent)
            if DateHelpers.startOfDay(date) == DateHelpers.today() {
                Button("Yesterday") {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                }
                .buttonStyle(RetroButtonStyle())
            }
            Spacer(minLength: 0)
        }
    }

    /// Validation message (only after a failed Save), Delete when editing, Save.
    private var footer: some View {
        HStack(spacing: 10) {
            Text(showProblem ? (problem ?? "") : "")
                .font(.plex(12, .semibold))
                .foregroundStyle(Theme.negative)
                .frame(maxWidth: .infinity, alignment: .leading)
            if editing != nil {
                Button("Delete") { delete() }
                    .buttonStyle(RetroButtonStyle(kind: .danger))
                    .accessibilityLabel("Delete this transaction")
            }
            Button("Save") { save() }
                .buttonStyle(RetroButtonStyle(kind: .primary))
        }
    }

    // MARK: Actions

    private func save() {
        guard problem == nil else {
            showProblem = true
            return
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        if let editing {
            editing.type = type
            editing.amount = amount
            editing.category = category
            editing.note = trimmedNote
            editing.date = DateHelpers.startOfDay(date)
            editing.updatedAt = .now
        } else {
            let t = Transaction(type: type, amount: amount, category: category, note: trimmedNote, date: DateHelpers.startOfDay(date))
            context.insert(t)
        }
        dismiss()
    }

    private func delete() {
        if let editing {
            context.delete(editing)
        }
        dismiss()
    }
}
