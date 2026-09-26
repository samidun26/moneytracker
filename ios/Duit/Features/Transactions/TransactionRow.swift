import SwiftUI

/// One row in Transaction History. Expenses use normal ink (most rows are
/// expenses — a wall of red is noise); income is green with "+". Ported
/// from src/features/transactions/TransactionRow.tsx, minus the
/// account/transfer parts (no Accounts in the MVP yet).
struct TransactionRow: View {
    var transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            IconBadge(icon: transaction.category?.icon ?? "❔", color: transaction.category?.color ?? .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(amountText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(transaction.type == .income ? Color(uiColor: .systemGreen) : .primary)
        }
        .padding(.vertical, 6)
    }

    private var title: String {
        let note = transaction.note.trimmingCharacters(in: .whitespaces)
        return note.isEmpty ? (transaction.category?.name ?? "Uncategorized") : note
    }

    private var subtitle: String? {
        let note = transaction.note.trimmingCharacters(in: .whitespaces)
        guard !note.isEmpty else { return nil }
        return transaction.category?.name
    }

    private var amountText: String {
        let sign = transaction.type == .income ? "+" : "\u{2212}"
        return sign + CurrencyFormatter.formatNumber(transaction.amount)
    }
}
