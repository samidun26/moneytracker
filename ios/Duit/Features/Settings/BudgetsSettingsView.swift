import SwiftUI
import SwiftData

/// Settings → Category budgets: a monthly limit per spending category.
/// Insights shows each one as a meter. (The overall "spending money" has its
/// own row in Settings, because it powers the Tanggal Tua battery.)
struct BudgetsSettingsView: View {
    let ledger: Ledger

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(Toaster.self) private var toaster
    @State private var target: Target?

    struct Target: Identifiable { let id: UUID }

    private var categories: [Category] { ledger.categories(of: .expense) }

    private func limit(of id: UUID) -> Int {
        ledger.budgets.first { $0.categoryID == id }?.amount ?? 0
    }

    var body: some View {
        RetroSheet(title: "Category budgets", tint: Theme.titleColors[2], icon: PixelIconData.panel, onClose: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A limit for one category in a month, like Food or Transport. Insights shows how much is left.")
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)
                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            if index > 0 { DottedDivider() }
                            row(category)
                        }
                    }
                    .retroSunk()
                }
                .padding(14)
            }
        }
        .sheet(item: $target) { target in
            if let category = ledger.category(id: target.id) {
                AmountEditorView(
                    title: category.name,
                    caption: "\(category.name) · per month",
                    note: "Set it to 0 to remove this budget.",
                    initial: limit(of: category.id)
                ) { value in save(value, for: category) }
            }
        }
    }

    private func row(_ category: Category) -> some View {
        let amount = limit(of: category.id)
        return Button { target = Target(id: category.id) } label: {
            HStack(spacing: 10) {
                IconBadge(icon: category.icon, color: category.color, size: 36)
                Text(category.name)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(amount > 0 ? "\(CurrencyFormatter.formatRpCompact(amount)) / month" : "No limit")
                    .font(.plex(13, .semibold))
                    .foregroundStyle(amount > 0 ? Theme.ink : Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
        .accessibilityLabel(category.name)
        .accessibilityValue(amount > 0 ? "\(CurrencyFormatter.formatRp(amount)) per month" : "No limit")
        .accessibilityHint("Set the monthly limit")
    }

    private func save(_ value: Int, for category: Category) {
        let existing = ledger.budgets.first { $0.categoryID == category.id }
        if value <= 0 {
            if let existing { context.delete(existing) }
            toaster.show("Removed the \(category.name) budget")
        } else if let existing {
            existing.amount = value
            toaster.show("\(category.name) budget: \(CurrencyFormatter.formatRp(value))")
        } else {
            context.insert(Budget(categoryID: category.id, amount: value))
            toaster.show("\(category.name) budget: \(CurrencyFormatter.formatRp(value))")
        }
        try? context.save()
    }
}
