import SwiftUI
import SwiftData

/// Settings, after the prototype's last tab: Look, Payday, Security and
/// Sync & data — plus the places where the real app needs to be set up,
/// which the prototype's sample data didn't (spending money, salary,
/// wallets, category budgets, bills and the payday split buckets).
struct SettingsView: View {
    let ledger: Ledger
    /// Alerts raised here use the root's retro alert.
    var onAlert: (RetroAlertContent) -> Void
    var onStartPayday: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(Toaster.self) private var toaster
    @AppStorage(Prefs.theme) private var theme = "auto"
    @AppStorage(Prefs.palette) private var palette = "candy"
    @AppStorage(Prefs.texture) private var texture = true
    @AppStorage(Prefs.paydayDay) private var paydayDay = Prefs.defaultPaydayDay
    @AppStorage(Prefs.salary) private var salary = 0
    @AppStorage(Prefs.faceLock) private var faceLock = false
    @Query private var buckets: [SplitBucket]

    enum Panel: String, Identifiable {
        case spending, salary, wallets, budgets, bills, buckets
        var id: String { rawValue }
    }

    @State private var panel: Panel?
    @State private var lockMethod = AppLock.methodName

    private struct ThemeOption: Identifiable {
        let id: String
        let label: String
        let hint: String
    }

    private let themes = [
        ThemeOption(id: "auto", label: "Automatic", hint: "follows iPhone"),
        ThemeOption(id: "day", label: "Day", hint: "bright paper"),
        ThemeOption(id: "night", label: "Night", hint: "soft navy"),
    ]
    private let presetPaydays = [1, 25, 28]

    var body: some View {
        ScrollView {
            RetroWindow(title: "Settings", tint: Theme.titleColors[4], icon: PixelIconData.panel) {
                VStack(spacing: 8) {
                    lookGroup
                    paydayGroup
                    moneyGroup
                    setupGroup
                    securityGroup
                    dataGroup
                    Text("Duit \(Self.version) · offline-first · made for iPhone")
                        .font(.plex(12))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(14)
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .sheet(item: $panel) { panel in
            switch panel {
            case .spending:
                AmountEditorView(
                    title: "Spending money",
                    caption: "Spending money · per month",
                    note: "What you can spend in a month, after rent, savings and bills. It powers the Tanggal Tua battery. Set it to 0 to turn the battery off.",
                    initial: ledger.overallBudget ?? 0
                ) { saveSpendingMoney($0) }
            case .salary:
                AmountEditorView(
                    title: "Monthly salary",
                    caption: "Salary · per month",
                    note: "Used by the Payday Split and for “work hours” in Insights. Set it to 0 if you'd rather not say.",
                    initial: salary
                ) { salary = $0 }
            case .wallets: WalletsSettingsView(ledger: ledger)
            case .budgets: BudgetsSettingsView(ledger: ledger)
            case .bills: BillsSettingsView(ledger: ledger)
            case .buckets: SplitBucketsView()
            }
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    // MARK: Look

    private var lookGroup: some View {
        RetroGroup(title: "Look") {
            ForEach(themes) { option in
                RetroOptionRow(label: option.label, hint: option.hint, isOn: theme == option.id) { theme = option.id }
            }
            ForEach(PaletteName.allCases) { option in
                RetroOptionRow(label: option.label, isOn: palette == option.rawValue, action: { palette = option.rawValue }) {
                    PaletteStrip(colors: option.swatches)
                }
                .accessibilityLabel("\(option.label) colors, \(option.hint)")
            }
            RetroOptionRow(label: "Desktop dots", hint: "subtle texture", isOn: texture, style: .check) { texture.toggle() }
        }
    }

    // MARK: Payday

    private func nextPayday(_ day: Int) -> String {
        "next: " + DateHelpers.formatPayday(PayCycle.period(today: ledger.today, paydayDay: day).nextPayday)
    }

    private var paydayGroup: some View {
        let custom = !presetPaydays.contains(paydayDay)
        return RetroGroup(title: "Payday") {
            ForEach(presetPaydays, id: \.self) { day in
                RetroOptionRow(
                    label: day == 1 ? "1st of the month" : DateHelpers.ordinal(day),
                    hint: nextPayday(day),
                    isOn: paydayDay == day
                ) { paydayDay = day }
            }
            Menu {
                ForEach(1...31, id: \.self) { day in
                    Button(DateHelpers.ordinal(day)) { paydayDay = day }
                }
            } label: {
                RetroOptionLabel(
                    label: custom ? "\(DateHelpers.ordinal(paydayDay)) of the month" : "Another day…",
                    hint: custom ? nextPayday(paydayDay) : nil,
                    isOn: custom
                )
            }
            .accessibilityLabel("Another day of the month")
            .accessibilityValue(custom ? DateHelpers.ordinal(paydayDay) : "")
            .accessibilityAddTraits(custom ? .isSelected : [])
            note("Tanggal Tua counts down to this day.")
        }
    }

    // MARK: Money

    private var moneyGroup: some View {
        RetroGroup(title: "Money") {
            RetroValueRow(
                label: "Spending money",
                value: ledger.overallBudget.map { CurrencyFormatter.formatRpCompact($0) } ?? "Not set",
                accessibilityHint: "Opens the keypad"
            ) { panel = .spending }
            note("What you can spend each month. It powers the battery on Today.")
            RetroValueRow(
                label: "Monthly salary",
                value: salary > 0 ? CurrencyFormatter.formatRpCompact(salary) : "Not set",
                accessibilityHint: "Opens the keypad"
            ) { panel = .salary }
            note("For the Payday Split and work hours in Insights.")
            if salary > 0 {
                RetroValueRow(
                    label: "Payday Split",
                    value: ledger.needsPaydaySplit ? "Ready" : "Open",
                    accessibilityHint: "Give your salary a job"
                ) { onStartPayday() }
            }
        }
    }

    // MARK: Setup

    private var setupGroup: some View {
        let categoryBudgets = ledger.budgets.filter { $0.categoryID != nil && $0.amount > 0 }.count
        let bills = ledger.rules.filter(\.active).count
        return RetroGroup(title: "Set up") {
            RetroValueRow(label: "Wallets", value: countText(ledger.activeAccounts.count, "wallet")) { panel = .wallets }
            RetroValueRow(label: "Category budgets", value: categoryBudgets == 0 ? "None" : "\(categoryBudgets) set") { panel = .budgets }
            RetroValueRow(label: "Bills & subscriptions", value: bills == 0 ? "None" : "\(bills)") { panel = .bills }
            RetroValueRow(label: "Payday split buckets", value: "\(buckets.count)") { panel = .buckets }
        }
    }

    private func countText(_ n: Int, _ noun: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s")"
    }

    // MARK: Security

    private var securityGroup: some View {
        RetroGroup(title: "Security") {
            RetroOptionRow(label: "Require \(lockMethod) to open", isOn: faceLock, style: .check) { toggleLock() }
            note("Your iPhone passcode always works as a backup. Duit never stores a password of its own.")
        }
    }

    private func toggleLock() {
        if faceLock {
            faceLock = false
            return
        }
        Task { @MainActor in
            switch await AppLock.authenticate(reason: "Turn on the lock for Duit") {
            case .success:
                faceLock = true
            case .unavailable:
                onAlert(RetroAlertContent(
                    title: "Set a passcode first",
                    message: "Duit locks with your iPhone's Face ID or passcode. Turn one on in the iPhone's Settings, then come back.",
                    icon: PixelIconData.caution
                ))
            case .failed:
                break
            }
        }
    }

    // MARK: Data

    private var dataGroup: some View {
        RetroGroup(title: "Sync & data") {
            note("Not connected. Everything stays on this iPhone.")
            FlowLayout(spacing: 12) {
                Button("Connect…") {
                    onAlert(RetroAlertContent(
                        title: "iCloud sync is coming",
                        message: "Duit keeps everything on this iPhone for now. Export CSV makes a copy you can keep or open in a spreadsheet.",
                        icon: PixelIconData.cloud
                    ))
                }
                .buttonStyle(RetroButtonStyle(small: true))

                ShareLink(
                    item: CSVFile(entries: ledger.entries, day: ledger.today),
                    preview: SharePreview("Duit transactions (CSV)")
                ) {
                    Text("Export CSV…")
                }
                .buttonStyle(RetroButtonStyle(small: true))
                .disabled(ledger.entries.isEmpty)

                Button("Reset all data…", action: askReset)
                    .buttonStyle(RetroButtonStyle(kind: .danger, small: true))
            }
            .padding(.top, 10)
        }
    }

    private func askReset() {
        let ctx = context
        let toaster = toaster
        onAlert(RetroAlertContent(
            title: "Reset all data?",
            message: "This erases every transaction, wallet, budget and bill on this iPhone and puts the starting wallets and categories back. It can't be undone. Export a CSV first if you want a copy.",
            icon: PixelIconData.caution,
            confirmLabel: "Erase everything",
            action: {
                DataReset.eraseEverything(in: ctx)
                toaster.show("All data erased")
            }
        ))
    }

    // MARK: Helpers

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.plex(12.5))
            .foregroundStyle(Theme.ink2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            .padding(.bottom, 6)
    }

    private func saveSpendingMoney(_ value: Int) {
        let existing = ledger.budgets.first { $0.categoryID == nil }
        if value <= 0 {
            if let existing { context.delete(existing) }
            toaster.show("Spending money cleared")
        } else {
            if let existing {
                existing.amount = value
            } else {
                context.insert(Budget(categoryID: nil, amount: value))
            }
            toaster.show("Spending money: \(CurrencyFormatter.formatRpCompact(value)) a month")
        }
        try? context.save()
    }
}
