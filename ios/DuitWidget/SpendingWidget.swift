import WidgetKit
import SwiftUI

// MARK: - Timeline

struct SpendEntry: TimelineEntry {
    let date: Date
    /// nil until the app has run once.
    let snapshot: WidgetSnapshot?
}

struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry {
        SpendEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        completion(SpendEntry(date: .now, snapshot: context.isPreview ? .sample : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        let now = Date()
        let entry = SpendEntry(date: now, snapshot: WidgetSnapshot.load())
        // The app pushes a reload whenever your data changes; this is only
        // the backstop that resets "today" after midnight if the app wasn't opened.
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(midnight.addingTimeInterval(5 * 60))))
    }
}

// MARK: - Widget

struct SpendingWidget: Widget {
    static let kind = "DuitSpending"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SpendProvider()) { entry in
            SpendingWidgetView(entry: entry)
        }
        .configurationDisplayName("Spending")
        .description("What you've spent today and this month, and your Tanggal Tua battery.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct SpendingWidgetView: View {
    let entry: SpendEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    private var snapshot: WidgetSnapshot? { entry.snapshot }
    private var colors: WidgetColors { WidgetColors(scheme: scheme, palette: snapshot?.palette ?? "candy") }
    private var hidden: Bool { snapshot?.hideAmounts ?? false }

    private func rp(_ n: Int) -> String { CurrencyFormatter.formatRpCompact(n) }
    private var today: Int { snapshot?.spentToday(at: entry.date) ?? 0 }
    private var month: Int { snapshot?.spentMonth(at: entry.date) ?? 0 }
    private var monthName: String {
        entry.date.formatted(.dateTime.month(.wide).locale(Locale(identifier: "en_US")))
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            default: small
            }
        }
        .widgetURL(AppRoute.today.url)
        .containerBackground(for: .widget) {
            switch family {
            case .systemSmall, .systemMedium: colors.paper
            default: Color.clear
            }
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(spacing: 0) {
            WidgetTitleBar(title: snapshot?.batteryFraction == nil ? "SPENT · \(monthName.uppercased())" : "TANGGAL TUA", tint: colors.titles[2], colors: colors)
            content(compact: true)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var medium: some View {
        VStack(spacing: 0) {
            WidgetTitleBar(title: "DUIT · \(monthName.uppercased())", tint: colors.titles[2], colors: colors)
            HStack(alignment: .top, spacing: 12) {
                content(compact: false)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                addButton
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// The numbers, shared by the small and medium layouts.
    @ViewBuilder
    private func content(compact: Bool) -> some View {
        if snapshot == nil {
            note("Open Duit once to start.")
        } else if hidden {
            VStack(alignment: .leading, spacing: 4) {
                Text("LOCKED").font(.pixel(16)).foregroundStyle(colors.ink)
                Text("Amounts are hidden while the app lock is on.").font(.plex(11)).foregroundStyle(colors.ink2)
            }
        } else if let snapshot, let percent = snapshot.batteryPercent, let cells = snapshot.batteryFilledCells {
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(percent)%").font(.pixel(compact ? 22 : 24)).foregroundStyle(snapshot.level == .low ? colors.negative : colors.ink)
                    Spacer(minLength: 0)
                }
                WidgetBatteryBar(cells: cells, fill: colors.batteryFill(snapshot.level), colors: colors)
                Text("\(rp(snapshot.allowancePerDay ?? 0)) a day")
                    .font(.plex(12, .bold)).foregroundStyle(colors.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text("Today \(rp(today)) · \(monthName.prefix(3)) \(rp(month))")
                    .font(.plex(10.5)).foregroundStyle(colors.ink2)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("SPENT").font(.plex(10, .bold)).tracking(1).foregroundStyle(colors.lcdInk)
                    .padding(.horizontal, 6).padding(.top, 4)
                Text(rp(month)).font(.lcd(compact ? 32 : 36)).foregroundStyle(colors.lcdInk)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 6).padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(colors.lcd)
            .overlay(Rectangle().strokeBorder(colors.line, lineWidth: 1))
            Text("Today \(rp(today))").font(.plex(11, .semibold)).foregroundStyle(colors.ink)
                .padding(.top, 2)
            if !compact {
                Text("Set your spending money in Settings to see the battery.").font(.plex(10.5)).foregroundStyle(colors.ink2)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.plex(12)).foregroundStyle(colors.ink2)
    }

    /// "+ New expense" — its own tap target in the medium widget.
    private var addButton: some View {
        Link(destination: AppRoute.addExpense.url) {
            VStack(spacing: 6) {
                WidgetPlus(color: colors.accentInk, length: 22, thickness: 7)
                Text("NEW")
                    .font(.pixel(11)).foregroundStyle(colors.accentInk)
            }
            .frame(width: 74)
            .frame(maxHeight: .infinity)
            .background(colors.accent)
            .overlay(Rectangle().strokeBorder(colors.line, lineWidth: 1))
        }
        .accessibilityLabel("New expense")
    }

    // MARK: Lock screen

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if snapshot == nil || hidden {
                Image(systemName: "lock.fill")
            } else if let fraction = snapshot?.batteryFraction, let percent = snapshot?.batteryPercent {
                Gauge(value: fraction) {
                    Text("Duit")
                } currentValueLabel: {
                    Text("\(percent)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                VStack(spacing: 0) {
                    Text(CurrencyFormatter.formatCompact(today)).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6)
                    Text("today").font(.system(size: 9))
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Duit").font(.headline)
            if snapshot == nil {
                Text("Open the app once")
            } else if hidden {
                Text("Locked")
            } else {
                Text("Today \(rp(today))")
                if let allowance = snapshot?.allowancePerDay, let percent = snapshot?.batteryPercent {
                    Text("\(rp(allowance)) a day · \(percent)%")
                } else {
                    Text("\(monthName.prefix(3)) \(rp(month))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text(snapshot == nil || hidden ? "Duit" : "Duit · today \(rp(today))")
    }
}
