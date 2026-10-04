import SwiftUI

/// Activity: every transaction, grouped by month and day. This is the first
/// version (the list from the earlier release, restyled); Wallets, search and
/// filters are added in the next step.
struct ActivityView: View {
    let ledger: Ledger
    var onEdit: (UUID) -> Void

    private struct Month: Identifiable {
        var start: Date
        var days: [ActivitySearch.DayGroup]
        var count: Int
        var id: Date { start }
    }

    private var months: [Month] {
        var out: [Month] = []
        for day in ActivitySearch.groups(ledger.entries) {
            if var last = out.last, DateHelpers.isSameMonth(last.start, day.date) {
                last.days.append(day)
                last.count += day.items.count
                out[out.count - 1] = last
            } else {
                out.append(Month(start: day.date, days: [day], count: day.items.count))
            }
        }
        return out
    }

    /// Each month gets one of the five title colors, chosen from the month
    /// itself so it doesn't change as transactions are added.
    private func titleTint(for month: Month) -> Color {
        let parts = Calendar.current.dateComponents([.year, .month], from: month.start)
        let index = ((parts.year ?? 0) * 12 + (parts.month ?? 0)) % Theme.titleColors.count
        return Theme.titleColors[index]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                if ledger.entries.isEmpty {
                    RetroWindow(title: "Nothing here yet", tint: Theme.titleColors[2], icon: PixelIconData.activity) {
                        Text("Tap Add to log your first transaction.")
                            .font(.plex(13))
                            .foregroundStyle(Theme.ink2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 22)
                    }
                } else {
                    ForEach(months) { month in
                        RetroWindow(title: DateHelpers.formatMonth(month.start), tint: titleTint(for: month), icon: PixelIconData.activity) {
                            CountBadge(count: month.count)
                        } content: {
                            VStack(spacing: 0) {
                                ForEach(month.days) { day in
                                    dayHeader(day)
                                    ForEach(Array(day.items.enumerated()), id: \.element.id) { index, entry in
                                        if index > 0 { DottedDivider() }
                                        Button { onEdit(entry.id) } label: { EntryRow(entry: entry) }
                                            .buttonStyle(RowPressStyle())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
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
