import SwiftUI
import SwiftData

/// The app's outermost view: applies the user's look (day / night /
/// automatic, and the palette) and keeps which tab is open when the palette
/// changes — a palette change rebuilds the screens (so every color is
/// re-read) but must not bounce you back to Today.
struct AppShell: View {
    @AppStorage(Prefs.theme) private var theme = "auto"
    @AppStorage(Prefs.palette) private var palette = "candy"
    @AppStorage(Prefs.faceLock) private var faceLock = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today
    @State private var toaster = Toaster()
    /// Starts locked when the lock is on, so the first screen is the lock.
    @State private var locked = UserDefaults.standard.bool(forKey: Prefs.faceLock)
    /// Bumped when the app locks: rebuilding the desk closes any open sheet,
    /// which would otherwise float above the lock screen.
    @State private var lockEpoch = 0

    private var scheme: ColorScheme? {
        switch theme {
        case "day": .light
        case "night": .dark
        default: nil
        }
    }

    var body: some View {
        ZStack {
            RootView(tab: $tab)
                .id("\(palette)-\(lockEpoch)")
            if faceLock && (locked || scenePhase != .active) {
                LockScreen(locked: locked, onUnlock: unlock)
            }
        }
        .environment(toaster)
        .preferredColorScheme(scheme)
        .tint(Theme.accent)
        .onChange(of: scenePhase) {
            if scenePhase == .background && faceLock {
                locked = true
                lockEpoch += 1
            }
        }
    }

    private func unlock() async {
        switch await AppLock.authenticate(reason: "Unlock Duit") {
        case .success:
            locked = false
        case .unavailable:
            // The passcode was removed from the iPhone; don't lock the user out.
            faceLock = false
            locked = false
        case .failed:
            break
        }
    }
}

/// The desk: app bar, the open screen, the toast and the taskbar, plus the
/// sheets that open over them.
struct RootView: View {
    @Binding var tab: AppTab

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Toaster.self) private var toaster

    @Query private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Query private var budgets: [Budget]
    @Query private var rules: [RecurringRule]
    @AppStorage(Prefs.paydayDay) private var paydayDay = Prefs.defaultPaydayDay
    @AppStorage(Prefs.salary) private var salary = 0

    @State private var composer: ComposerRequest?
    @State private var balanceTarget: BalanceCheckTarget?
    @State private var alert: RetroAlertContent?
    @State private var booting = false
    @State private var splitOpen = false

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
        .overlay {
            if booting {
                PaydayBootView(salary: salary)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            RetroAppBar(title: tab.title, battery: ledger.battery) { tab = .today }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RetroTaskbar(selection: $tab) { composer = .add(.expense) }
        }
        .sheet(item: $composer) { request in
            AddTransactionView(request: request, ledger: ledger)
        }
        .sheet(item: $balanceTarget) { target in
            BalanceCheckView(ledger: ledger, initialAccountID: target.id)
        }
        .sheet(isPresented: $splitOpen) {
            PaydaySplitView(ledger: ledger)
        }
        .retroAlert($alert)
        .task {
            RecurringPoster.postDue(in: context)
            announceSetAsideStore()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { RecurringPoster.postDue(in: context) }
        }
    }

    /// The "PAYDAY!" boot screen, then the Payday Split sheet.
    private func startPayday() {
        guard salary > 0, !booting else { return }
        composer = nil
        balanceTarget = nil
        alert = nil
        withAnimation { booting = true }
        let pause: Duration = reduceMotion ? .milliseconds(400) : .milliseconds(2100)
        Task { @MainActor in
            try? await Task.sleep(for: pause)
            withAnimation { booting = false }
            splitOpen = true
        }
    }

    /// If an update left the old data unreadable, Store set it aside and
    /// started fresh; say so once instead of letting it look like data loss.
    private func announceSetAsideStore() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Store.resetFlagKey) else { return }
        defaults.removeObject(forKey: Store.resetFlagKey)
        alert = RetroAlertContent(
            title: "Duit started fresh",
            message: "After the update, Duit couldn't read your old data, so it set that file aside on this iPhone and started with an empty one. Nothing was deleted.",
            icon: PixelIconData.caution
        )
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
                onCheckBalance: { balanceTarget = BalanceCheckTarget(id: $0) },
                onPayday: startPayday
            )
        case .activity:
            ActivityView(
                ledger: ledger,
                onEdit: { composer = .edit($0) },
                onCheckBalance: { balanceTarget = BalanceCheckTarget(id: $0) }
            )
        case .insights:
            InsightsView(ledger: ledger, onGoSettings: { tab = .settings })
        case .settings:
            SettingsView(ledger: ledger, onAlert: { alert = $0 }, onStartPayday: startPayday)
        }
    }
}
