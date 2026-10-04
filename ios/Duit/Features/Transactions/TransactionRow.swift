import SwiftUI

/// One row in Transaction History. Expenses use normal ink (most rows are
/// expenses — a wall of red is noise); income is green with "+". Ported
/// from src/features/transactions/TransactionRow.tsx, minus the
/// account/transfer parts (no Accounts in the MVP yet). Styled after the
/// prototype's `.row`: tile, name over a dim sub-line, amount on the right.
struct TransactionRow: View {
    var transaction: Transaction

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(icon: transaction.category?.icon ?? "❔", color: transaction.category?.color ?? .gray, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.plex(11.5))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(amountText)
                .font(.plex(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.type == .income ? Theme.positive : Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
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
