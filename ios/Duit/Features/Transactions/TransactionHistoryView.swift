import SwiftUI
import SwiftData

/// The Transaction History screen (MVP item 5) — transactions grouped by
/// month (one retro window each) and by day with a daily net. Ports
/// src/features/transactions/TransactionList.tsx; the "Show earlier"
/// pagination is dropped for now, SwiftData/@Query doesn't need it at MVP
/// data volumes.
///
/// This is also the temporary app root (see DuitApp.swift) until Dashboard
/// exists — MVP item 1, next after this slice is stable.
struct TransactionHistoryView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var editing: Transaction?
    @State private var adding = false

    private struct Day: Identifiable {
        var date: Date
        var items: [Transaction]
        var net: Int
        var id: Date { date }
    }

    private struct Month: Identifiable {
        var start: Date
        var days: [Day]
        var count: Int
        var id: Date { start }
    }

    private var days: [Day] {
        var groups: [Day] = []
        for t in transactions {
            let day = DateHelpers.startOfDay(t.date)
            let delta = t.type == .income ? t.amount : -t.amount
            if var last = groups.last, last.date == day {
                last.items.append(t)
                last.net += delta
                groups[groups.count - 1] = last
            } else {
                groups.append(Day(date: day, items: [t], net: delta))
            }
        }
        return groups
    }

    private var months: [Month] {
        var groups: [Month] = []
        for day in days {
            if var last = groups.last, DateHelpers.isSameMonth(last.start, day.date) {
                last.days.append(day)
                last.count += day.items.count
                groups[groups.count - 1] = last
            } else {
                groups.append(Month(start: day.date, days: [day], count: day.items.count))
            }
        }
        return groups
    }

    /// Each month gets one of the five candy title colors, picked from the
    /// month itself so it doesn't change as transactions are added.
    private func titleTint(for month: Month) -> Color {
        let parts = Calendar.current.dateComponents([.year, .month], from: month.start)
        let index = ((parts.year ?? 0) * 12 + (parts.month ?? 0)) % Theme.titleColors.count
        return Theme.titleColors[index]
    }

    var body: some View {
        ZStack {
            DeskBackground()
            ScrollView {
                LazyVStack(spacing: 18) {
                    if transactions.isEmpty {
                        emptyState
                    } else {
                        ForEach(months) { month in
                            monthWindow(month)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { RetroAppBar(title: "Activity") }
        .safeAreaInset(edge: .bottom, spacing: 0) { RetroTaskbar { adding = true } }
        .sheet(isPresented: $adding) {
            AddTransactionView()
        }
        .sheet(item: $editing) { t in
            AddTransactionView(editing: t)
        }
    }

    private var emptyState: some View {
        RetroWindow(title: "Nothing here yet", tint: Theme.titleColors[2]) {
            Text("Tap Add to log your first transaction.")
                .font(.plex(13))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 22)
        }
    }

    private func monthWindow(_ month: Month) -> some View {
        RetroWindow(title: DateHelpers.formatMonth(month.start), tint: titleTint(for: month)) {
            CountBadge(count: month.count)
        } content: {
            VStack(spacing: 0) {
                ForEach(month.days) { day in
                    dayHeader(day)
                    ForEach(Array(day.items.enumerated()), id: \.element.id) { index, t in
                        if index > 0 { DottedDivider() }
                        Button {
                            editing = t
                        } label: {
                            TransactionRow(transaction: t)
                        }
                        .buttonStyle(RowPressStyle())
                    }
                }
            }
        }
    }

    /// "Today" / "Wed, 24 Sep" with the day's net on the right (the
    /// prototype's `.dayhead`).
    private func dayHeader(_ day: Day) -> some View {
        HStack {
            Text(DateHelpers.formatDayLabel(day.date))
            Spacer()
            if day.net != 0 {
                Text(CurrencyFormatter.formatSigned(day.net))
            }
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

/// Tapped rows flash to the face color (the prototype's `.row:active`).
private struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.face : Color.clear)
    }
}
