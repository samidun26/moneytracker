import SwiftUI

/// Activity — after the prototype's second tab: a Wallets window (tap one to
/// check it against your bank or e-wallet app) and a Transactions window with
/// search, All / Money out / Money in, and the list grouped by month and day.
struct ActivityView: View {
    let ledger: Ledger
    var onEdit: (UUID) -> Void
    var onCheckBalance: (UUID) -> Void

    @State private var query = ""
    @State private var filter: ActivityFilter = .all
    /// Rendering thousands of rows at once is slow, so older ones load on request.
    @State private var limit = 150

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                walletsWindow
                transactionsWindow
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Wallets

    private var walletsWindow: some View {
        let total = Balances.netWorth(ledger.accountRefs, balances: ledger.balances)
        return RetroWindow(title: "Wallets", tint: Theme.titleColors[1], icon: PixelIconData.cash) {
            Text("Total \(CurrencyFormatter.formatRpCompact(total))")
                .font(.plex(12, .bold))
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(ledger.activeAccounts) { account in
                        walletButton(account)
                    }
                }
                Text("Tap a wallet to check it against your bank or e-wallet app.")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 12)
            }
            .padding(14)
        }
    }

    private func walletButton(_ account: Account) -> some View {
        let balance = ledger.balances[account.id] ?? 0
        return Button { onCheckBalance(account.id) } label: {
            VStack(spacing: 5) {
                PixelTile(rects: account.kind.icon, color: account.color.color, size: 44)
                Text(account.name)
                    .font(.plex(12, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(CurrencyFormatter.formatCompact(balance))
                    .font(.plex(13, .semibold))
                    .foregroundStyle(balance < 0 ? Theme.negative : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(account.name) \(CurrencyFormatter.formatRp(balance)). Check balance.")
    }

    // MARK: Transactions

    private var transactionsWindow: some View {
        let filtered = ledger.entries.filter { ActivitySearch.matches($0, filter: filter, query: query) }
        let groups = ActivitySearch.groups(Array(filtered.prefix(limit)))
        return RetroWindow(title: "Transactions", tint: Theme.titleColors[3], icon: PixelIconData.activity) {
            LazyVStack(spacing: 0) {
                VStack(spacing: 12) {
                    searchField
                    RetroTabs(items: ActivityFilter.allCases, label: { $0.label }, selection: $filter)
                }
                .padding(14)

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    if index == 0 || !DateHelpers.isSameMonth(groups[index - 1].date, group.date) {
                        monthHeader(group.date)
                    }
                    dayHeader(group)
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, entry in
                        if itemIndex > 0 { DottedDivider() }
                        Button { onEdit(entry.id) } label: { EntryRow(entry: entry) }
                            .buttonStyle(RowPressStyle())
                    }
                }

                if filtered.isEmpty {
                    Text(ledger.entries.isEmpty
                        ? "Nothing here yet. Tap Add to log your first transaction."
                        : "No matches. Try “kopi”, “grab” or an amount like 32000.")
                        .font(.plex(13))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 22)
                } else if filtered.count > limit {
                    Button { limit += 150 } label: {
                        Text("Show earlier")
                            .font(.pixel(14))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Theme.face)
                            .overlay(alignment: .top) { Theme.line.frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            PixelIcon(rects: PixelIconData.search, unit: 1)
                .foregroundStyle(Theme.ink2)
            TextField(
                "Search transactions",
                text: $query,
                prompt: Text("Search transactions").foregroundStyle(Theme.ink2)
            )
            .font(.plex(16))
            .foregroundStyle(Theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
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
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .frame(minHeight: 44)
        .retroSunk()
    }

    // MARK: Headers

    private func monthHeader(_ date: Date) -> some View {
        Text(DateHelpers.formatMonth(date))
            .font(.pixel(14))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Theme.face2)
            .overlay(alignment: .top) { Theme.line.frame(height: 1) }
            .accessibilityAddTraits(.isHeader)
    }

    /// "Today" / "Wed, 24 Sep" with the day's net on the right (`.dayhead`).
    private func dayHeader(_ day: ActivitySearch.DayGroup) -> some View {
        HStack {
            Text(DateHelpers.formatDayLabel(day.date, today: ledger.today))
            Spacer()
            if day.net != 0 { Text(CurrencyFormatter.formatSigned(day.net)) }
        }
        .font(.plex(11, .bold))
        .tracking(0.9)
        .textCase(.uppercase)
        .foregroundStyle(Theme.ink2)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity)
        .background(Theme.face)
        .overlay(alignment: .top) { Theme.line.frame(height: 1) }
        .overlay(alignment: .bottom) { DottedDivider() }
        .accessibilityAddTraits(.isHeader)
    }
}
