import SwiftUI
import SwiftData

/// The Transaction History screen (MVP item 5) — transactions grouped by
/// day with a daily net, and month dividers. Ports
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

    private struct Day {
        var date: Date
        var items: [Transaction]
        var net: Int
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

    var body: some View {
        NavigationStack {
            List {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "tray",
                        description: Text("Tap + to log your first transaction.")
                    )
                } else {
                    ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                        let newMonth = index == 0 || !DateHelpers.isSameMonth(days[index - 1].date, day.date)
                        Section {
                            ForEach(day.items) { t in
                                Button {
                                    editing = t
                                } label: {
                                    TransactionRow(transaction: t)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 2) {
                                if newMonth {
                                    Text(DateHelpers.formatMonth(day.date))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .padding(.bottom, 2)
                                }
                                HStack {
                                    Text(DateHelpers.formatDayLabel(day.date))
                                    Spacer()
                                    if day.net != 0 {
                                        Text(CurrencyFormatter.formatSigned(day.net))
                                    }
                                }
                            }
                            .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $adding) {
                AddTransactionView()
            }
            .sheet(item: $editing) { t in
                AddTransactionView(editing: t)
            }
        }
    }
}
