import SwiftUI
import SwiftData

/// Add/edit a transaction — ports src/features/transactions/Composer.tsx,
/// minus the account/transfer picker (no Accounts in the MVP yet; every
/// transaction is against a single implicit balance until that slice
/// lands — see docs/IOS_NATIVE_PLAN.md §3).
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

    private var amountDisplayText: String {
        if showProblem, amount <= 0 { return "Enter an amount" }
        return "Rp \(CurrencyFormatter.formatNumber(amount))"
    }

    /// Matches the web composer's date input `max` (src/features/transactions/Composer.tsx: `addDays(today, 366)`).
    private var maxDate: Date {
        Calendar.current.date(byAdding: .day, value: 366, to: DateHelpers.today()) ?? DateHelpers.today()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Transaction type", selection: $type) {
                    Text("Expense").tag(TransactionType.expense)
                    Text("Income").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: type) {
                    if let category, category.kind != type { self.category = nil }
                }

                Text(amountDisplayText)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(amount == 0 ? .secondary : (type == .income ? Color(uiColor: .systemGreen) : .primary))
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                        ForEach(kindCategories) { c in
                            Button {
                                category = c
                            } label: {
                                VStack(spacing: 4) {
                                    IconBadge(icon: c.icon, color: c.color)
                                    Text(c.name)
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(category == c ? .primary : .secondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                                .background(category == c ? Color(uiColor: .tertiarySystemFill) : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        DatePicker(
                            "Date",
                            selection: $date,
                            in: ...maxDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        if DateHelpers.startOfDay(date) == DateHelpers.today() {
                            Button("Yesterday") {
                                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    TextField("Add a note (e.g. Kopi Kenangan)", text: $note)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Keypad { key in
                    amount = applyKey(amount, key)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)

                Button {
                    save()
                } label: {
                    Text(showProblem ? (problem ?? "Save") : "Save")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .navigationTitle(editing == nil ? (type == .income ? "New income" : "New expense") : "Edit \(type.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if editing != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) {
                            delete()
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

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
