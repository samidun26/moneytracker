import SwiftUI
import SwiftData

/// Settings → Bills & subscriptions: things that repeat (rent, Netflix,
/// internet). A bill either logs itself on its day, or shows up in To do on
/// Today until you tap Paid or Skip.
struct BillsSettingsView: View {
    let ledger: Ledger

    @Environment(\.dismiss) private var dismiss
    @State private var target: BillTarget?

    enum BillTarget: Identifiable {
        case new
        case existing(UUID)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let id): id.uuidString
            }
        }
    }

    private var rules: [RecurringRule] {
        ledger.rules.sorted { $0.note.localizedCaseInsensitiveCompare($1.note) == .orderedAscending }
    }

    var body: some View {
        RetroSheet(title: "Bills & subscriptions", tint: Theme.titleColors[2], icon: PixelIconData.bulb, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Rent, internet, Netflix. Duit can log them for you on the day, or remind you in To do.")
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)

                    if rules.isEmpty {
                        Text("No bills yet.")
                            .font(.plex(13))
                            .foregroundStyle(Theme.ink2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                                if index > 0 { DottedDivider() }
                                row(rule)
                            }
                        }
                        .retroSunk()
                    }

                    Button("Add a bill") { target = .new }
                        .buttonStyle(RetroButtonStyle(kind: .primary))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                .padding(14)
            }
        }
        .sheet(item: $target) { target in
            switch target {
            case .new: BillEditorView(ledger: ledger, ruleID: nil)
            case .existing(let id): BillEditorView(ledger: ledger, ruleID: id)
            }
        }
    }

    private func row(_ rule: RecurringRule) -> some View {
        let name = rule.note.isEmpty ? (rule.category?.name ?? "Bill") : rule.note
        let how = !rule.active ? "paused" : (rule.autoPost ? "logs itself" : "reminds you")
        return Button { target = .existing(rule.id) } label: {
            HStack(spacing: 10) {
                PixelTile(
                    rects: CategoryPixelIcon.rects(for: rule.category?.icon ?? ""),
                    fallback: rule.category?.icon ?? "📦",
                    color: (rule.category?.color ?? .gray).color,
                    size: 36
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.plex(14, .semibold))
                        .foregroundStyle(rule.active ? Theme.ink : Theme.ink2)
                        .lineLimit(1)
                    Text("\(rule.recurrence.summary) · \(how)")
                        .font(.plex(11.5))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(CurrencyFormatter.formatRpCompact(rule.amount))
                    .font(.plex(13, .semibold))
                    .foregroundStyle(rule.active ? Theme.ink : Theme.ink2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel(name)
        .accessibilityValue("\(CurrencyFormatter.formatRp(rule.amount)), \(rule.recurrence.summary), \(how)")
        .accessibilityHint("Edit this bill")
    }
}

// MARK: - Editor

struct BillEditorView: View {
    let ledger: Ledger
    /// nil = a new bill.
    let ruleID: UUID?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster

    @State private var name: String
    @State private var amount: Int
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var frequency: Frequency
    @State private var start: Date
    @State private var autoPost: Bool
    @State private var active: Bool
    @State private var editingAmount = false
    @State private var alert: RetroAlertContent?

    init(ledger: Ledger, ruleID: UUID?) {
        self.ledger = ledger
        self.ruleID = ruleID
        let rule = ledger.rules.first { $0.id == ruleID }
        let defaultCategory = ledger.category(named: "Bills & Utilities", kind: .expense)
        _name = State(initialValue: rule?.note ?? "")
        _amount = State(initialValue: rule?.amount ?? 0)
        _categoryID = State(initialValue: rule?.category?.id ?? defaultCategory?.id)
        _accountID = State(initialValue: rule?.account?.id ?? AccountDefaults.expense(ledger.accountRefs, last: AccountDefaults.read(Prefs.lastExpenseAccount)))
        _frequency = State(initialValue: rule?.frequency ?? .monthly)
        _start = State(initialValue: rule?.startDate ?? ledger.today)
        _autoPost = State(initialValue: rule?.autoPost ?? false)
        _active = State(initialValue: rule?.active ?? true)
    }

    private var rule: RecurringRule? { ledger.rules.first { $0.id == ruleID } }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && amount > 0 }
    private var categoryName: String { ledger.category(id: categoryID)?.name ?? "No category" }
    private var accountName: String { ledger.account(accountID)?.name ?? "No wallet" }

    var body: some View {
        RetroSheet(
            title: rule == nil ? "New bill" : "Edit bill",
            tint: Theme.titleColors[2],
            icon: PixelIconData.bulb,
            closeLabel: "Close without saving",
            onClose: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RetroTextField(caption: "Name", placeholder: "Rent, Netflix, internet…", text: $name)

                    RetroValueRow(label: "Amount", value: amount > 0 ? CurrencyFormatter.formatRp(amount) : "Set amount", accessibilityHint: "Opens the keypad") {
                        editingAmount = true
                    }
                    .retroSunk()

                    pickerRow("Category", value: categoryName) {
                        ForEach(ledger.categories(of: .expense), id: \.id) { category in
                            Button(category.name) { categoryID = category.id }
                        }
                    }

                    pickerRow("Pay from", value: accountName) {
                        ForEach(ledger.activeAccounts, id: \.id) { account in
                            Button(account.name) { accountID = account.id }
                        }
                    }

                    pickerRow("Repeats", value: frequency.label) {
                        ForEach(Frequency.allCases, id: \.self) { option in
                            Button(option.label) { frequency = option }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        DatePicker(selection: $start, displayedComponents: .date) {
                            Text(rule == nil ? "First due" : "Starts")
                                .font(.plex(15))
                                .foregroundStyle(Theme.ink)
                        }
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                        .retroSunk()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        RetroOptionRow(label: "Log it automatically", isOn: autoPost, style: .check) { autoPost.toggle() }
                        Text(autoPost
                            ? (start < ledger.today ? "Dates that have already passed are logged right away." : "Duit logs it on the day, so you never have to.")
                            : "It shows up in To do on Today, and you tap Paid or Skip.")
                            .font(.plex(12))
                            .foregroundStyle(Theme.ink2)
                            .padding(.leading, 34)
                    }

                    if rule != nil {
                        RetroOptionRow(label: "Active", hint: "turn off to pause", isOn: active, style: .check) { active.toggle() }
                    }

                    HStack(spacing: 12) {
                        if rule != nil {
                            Button("Delete", action: askDelete)
                                .buttonStyle(RetroButtonStyle(kind: .danger))
                        }
                        Spacer()
                        Button("Cancel") { dismiss() }
                            .buttonStyle(RetroButtonStyle())
                        Button("Save", action: save)
                            .buttonStyle(RetroButtonStyle(kind: .primary))
                            .disabled(!canSave)
                            .opacity(canSave ? 1 : 0.5)
                    }
                    .padding(.trailing, 4)
                }
                .padding(14)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $editingAmount) {
            AmountEditorView(title: "Bill amount", caption: "Amount · each time", initial: amount, allowZero: false) { amount = $0 }
        }
        .retroAlert($alert)
    }

    private func pickerRow<Options: View>(_ caption: String, value: String, @ViewBuilder options: () -> Options) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.plex(11, .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ink2)
            Menu {
                options()
            } label: {
                RetroPopupLabel(text: value)
            }
            .accessibilityLabel(caption)
            .accessibilityValue(value)
        }
    }

    // MARK: Actions

    private func save() {
        guard canSave else { return }
        let category = ledger.category(id: categoryID)
        let account = ledger.account(accountID)
        if let rule {
            rule.note = trimmedName
            rule.amount = amount
            rule.category = category
            rule.account = account
            rule.frequency = frequency
            rule.startDate = DateHelpers.startOfDay(start)
            rule.autoPost = autoPost
            rule.active = active
        } else {
            context.insert(RecurringRule(
                type: .expense,
                amount: amount,
                account: account,
                category: category,
                note: trimmedName,
                frequency: frequency,
                interval: 1,
                startDate: DateHelpers.startOfDay(start),
                autoPost: autoPost
            ))
        }
        try? context.save()
        RecurringPoster.postDue(in: context)
        toaster.show("Saved \(trimmedName)")
        dismiss()
    }

    private func askDelete() {
        guard let rule else { return }
        let ctx = context
        let doomedID = rule.id
        let label = trimmedName.isEmpty ? "this bill" : trimmedName
        let toaster = toaster
        let close = dismiss
        alert = RetroAlertContent(
            title: "Delete \(label)?",
            message: "Bills it already logged stay in your history. It just stops repeating.",
            icon: PixelIconData.caution,
            confirmLabel: "Delete",
            action: {
                var descriptor = FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.id == doomedID })
                descriptor.fetchLimit = 1
                if let doomed = try? ctx.fetch(descriptor).first {
                    ctx.delete(doomed)
                    try? ctx.save()
                }
                toaster.show("Deleted \(label)")
                close()
            }
        )
    }
}
