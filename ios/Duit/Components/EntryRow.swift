import SwiftUI

/// The prototype's list row (`.row`): a tile, the name over a dim sub-line,
/// and the amount on the right. Used by Today's Recent and by Activity.
struct EntryRow: View {
    let entry: Entry

    /// The transfer tile color (the prototype's `cc-lilac`).
    static let transferColor = Color(hex: 0xC7C3E6)

    var body: some View {
        HStack(spacing: 10) {
            PixelTile(rects: tileIcon, fallback: entry.categoryIcon ?? "", color: tileColor, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if !subtitle.isEmpty {
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
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.displayName), \(CurrencyFormatter.formatRp(entry.amount)), \(DateHelpers.formatDayLabel(entry.date))")
        .accessibilityHint("Tap to edit")
    }

    private var tileIcon: PixelRects? {
        entry.type == .transfer ? PixelIconData.transfer : CategoryPixelIcon.rects(for: entry.categoryIcon ?? "")
    }

    private var tileColor: Color {
        entry.type == .transfer ? EntryRow.transferColor : (entry.categoryColor ?? .gray).color
    }

    /// "Coffee & Snacks · GoPay", "Bank → GoPay", or just the wallet when the
    /// title already is the category.
    private var subtitle: String {
        if entry.type == .transfer {
            return "\(entry.accountName ?? "?") → \(entry.toAccountName ?? "?")"
        }
        let wallet = entry.accountName ?? ""
        if entry.title.isEmpty || entry.title == entry.categoryName { return wallet }
        let category = entry.categoryName ?? ""
        return wallet.isEmpty ? category : "\(category) · \(wallet)"
    }

    private var amountText: String {
        switch entry.type {
        case .income: "+" + CurrencyFormatter.formatNumber(entry.amount)
        case .expense: "\u{2212}" + CurrencyFormatter.formatNumber(entry.amount)
        case .transfer: CurrencyFormatter.formatNumber(entry.amount)
        }
    }

    private var amountColor: Color {
        switch entry.type {
        case .income: Theme.positive
        case .expense: Theme.ink
        case .transfer: Theme.ink2
        }
    }
}

/// Tapped rows flash to the face color (the prototype's `.row:active`).
struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.face : Color.clear)
    }
}

/// Lays chips out left to right and wraps to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    private func arrange(in maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return (positions, CGSize(width: width, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }
}
