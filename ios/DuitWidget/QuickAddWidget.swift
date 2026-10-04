import WidgetKit
import SwiftUI

// MARK: - Timeline

struct QuickAddEntry: TimelineEntry {
    let date: Date
    let palette: String
}

struct QuickAddProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry { QuickAddEntry(date: .now, palette: "candy") }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: .now, palette: WidgetSnapshot.load()?.palette ?? "candy"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        // Nothing here changes during the day, only when the palette does
        // (the app reloads this widget then).
        completion(Timeline(entries: [QuickAddEntry(date: .now, palette: WidgetSnapshot.load()?.palette ?? "candy")], policy: .never))
    }
}

// MARK: - Widget

struct QuickAddWidget: Widget {
    static let kind = "DuitQuickAdd"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickAddProvider()) { entry in
            QuickAddWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick add")
        .description("One tap opens Duit on a new expense.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct QuickAddWidgetView: View {
    let entry: QuickAddEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    private var colors: WidgetColors { WidgetColors(scheme: scheme, palette: entry.palette) }

    var body: some View {
        Group {
            if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "plus").font(.system(size: 22, weight: .bold))
                }
            } else {
                home
            }
        }
        .widgetURL(AppRoute.addExpense.url)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New expense")
        .containerBackground(for: .widget) {
            family == .accessoryCircular ? Color.clear : colors.paper
        }
    }

    private var home: some View {
        VStack(spacing: 0) {
            WidgetTitleBar(title: "NEW EXPENSE", tint: colors.titles[0], colors: colors)
            VStack(spacing: 8) {
                WidgetPlus(color: colors.accentInk, length: 34, thickness: 10)
                    .frame(width: 64, height: 64)
                    .background(colors.accent)
                    .overlay(Rectangle().strokeBorder(colors.line, lineWidth: 1))
                Text("Tap to log")
                    .font(.plex(11, .semibold))
                    .foregroundStyle(colors.ink2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
