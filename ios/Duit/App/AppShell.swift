import SwiftUI
import SwiftData

/// The app's outermost view: applies the user's look (day / night /
/// automatic, and the palette) and keeps which tab is open when the palette
/// changes — a palette change rebuilds the screens (so every color is
/// re-read) but must not bounce you back to Today.
struct AppShell: View {
    @AppStorage(Prefs.theme) private var theme = "auto"
    @AppStorage(Prefs.palette) private var palette = "candy"
    @State private var tab: AppTab = .today
    @State private var toaster = Toaster()

    private var scheme: ColorScheme? {
        switch theme {
        case "day": .light
        case "night": .dark
        default: nil
        }
    }

    var body: some View {
        RootView(tab: $tab)
            .id(palette)
            .environment(toaster)
            .preferredColorScheme(scheme)
            .tint(Theme.accent)
    }
}

/// The desk: app bar, the open screen, the toast and the taskbar, plus the
/// sheets that open over them.
struct RootView: View {
    @Binding var tab: AppTab

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Toaster.self) private var toaster

    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var budgets: [Budget]
    @Query private var rules: [RecurringRule]
    @AppStorage(Prefs.paydayDay) private var paydayDay = Prefs.defaultPaydayDay
    @AppStorage(Prefs.salary) private var salary = 0

    @State private var composer: ComposerRequest?
    @State private var alert: RetroAlertContent?

    var body: some View {
        let ledger = Ledger(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            budgets: budgets,
            rules: rules,
            paydayDay: paydayDay,
            salary: salary
        )
        ZStack {
            DeskBackground()
            screen(ledger)
        }
        .overlay(alignment: .bottom) {
            if let message = toaster.current {
                ToastView(message: message) { toaster.performUndo() }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: toaster.current?.id)
        .safeAreaInset(edge: .top, spacing: 0) {
            RetroAppBar(title: tab.title, battery: ledger.battery) { tab = .today }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RetroTaskbar(selection: $tab) { composer = .add(.expense) }
        }
        .sheet(item: $composer) { request in
            AddTransactionView(request: request, ledger: ledger)
        }
        .retroAlert($alert)
        .task { RecurringPoster.postDue(in: context) }
        .onChange(of: scenePhase) {
            if scenePhase == .active { RecurringPoster.postDue(in: context) }
        }
    }

    @ViewBuilder
    private func screen(_ ledger: Ledger) -> some View {
        switch tab {
        case .today:
            TodayView(
                ledger: ledger,
                onEdit: { composer = .edit($0) },
                onGoActivity: { tab = .activity },
                onGoSettings: { tab = .settings },
                onCheckBalance: { _ in
                    alert = RetroAlertContent(
                        title: "Balance Check",
                        message: "Comparing a wallet with your bank or e-wallet app arrives in the next update.",
                        icon: PixelIconData.search
                    )
                },
                onPayday: { tab = .settings }
            )
        case .activity:
            ActivityView(ledger: ledger, onEdit: { composer = .edit($0) })
        case .insights:
            InsightsView(ledger: ledger)
        case .settings:
            SettingsView(ledger: ledger)
        }
    }
}
