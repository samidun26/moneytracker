import SwiftUI

/// Insights, after the prototype's third tab: three sections under one
/// switch — Month (where the money went), Prices (what the things you
/// always buy now cost) and Habits (the Time Machine and the Worth-it
/// report). Everything is read from the user's own transactions.
struct InsightsView: View {
    let ledger: Ledger
    var onGoSettings: () -> Void

    enum Page: CaseIterable, Hashable {
        case month, prices, habits

        var label: String {
            switch self {
            case .month: "Month"
            case .prices: "Prices"
            case .habits: "Habits"
            }
        }
    }

    @State private var page: Page = .month
    private let topAnchor = "insights-top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    RetroSegmented(items: Page.allCases, label: { $0.label }, selection: $page)
                        .id(topAnchor)
                        .padding(.trailing, 3)
                    switch page {
                    case .month: MonthSection(ledger: ledger, onGoSettings: onGoSettings)
                    case .prices: PricesSection(ledger: ledger)
                    case .habits: HabitsSection(ledger: ledger)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .onChange(of: page) { proxy.scrollTo(topAnchor, anchor: .top) }
        }
    }
}

// MARK: - Shared bits

/// The tile for a category (its pixel icon on its color), or a gray box
/// when the spending has no category.
private struct CategoryTile: View {
    var category: Category?
    var size: CGFloat = 36

    var body: some View {
        if let category {
            IconBadge(icon: category.icon, color: category.color, size: size)
        } else {
            PixelTile(rects: PixelIconData.box, color: CategoryColor.gray.color, size: size)
        }
    }
}

private func compact(_ n: Int) -> String { CurrencyFormatter.formatRpCompact(n) }

/// What a mie ayam costs when the user hasn't logged one yet, so the
/// "Mie ayam" unit still means something. The note says it's an assumption.
private let assumedBowlPrice = 20_000

// MARK: - Month

private struct MonthSection: View {
    let ledger: Ledger
    var onGoSettings: () -> Void

    @State private var unit: Insights.MoneyUnit = .rupiah
    @State private var selectedColumn = 5

    private var month: MonthKey { ledger.currentMonth }
    private var trend: [Insights.TrendPoint] {
        Insights.monthlyTrend(ledger.entries, endMonth: month, months: 6)
    }
    private var current: Insights.TrendPoint {
        trend.last ?? Insights.TrendPoint(month: month, income: 0, expense: 0)
    }

    private var loggedBowlPrice: Int? { PriceTracker.latestPrice(containing: "mie ayam", entries: ledger.entries) }
    private var bowlPrice: Int { loggedBowlPrice ?? assumedBowlPrice }
    private var hourPrice: Int { Insights.hourPrice(salary: ledger.salary) }

    /// Work hours need a salary; without one the numbers stay in rupiah.
    private var shownUnit: Insights.MoneyUnit {
        unit == .hours && hourPrice == 0 ? .rupiah : unit
    }

    private func lcd(_ n: Int) -> String {
        Insights.lcdText(n, unit: shownUnit, bowlPrice: bowlPrice, hourPrice: hourPrice)
    }

    private var unitNote: String {
        switch unit {
        case .rupiah:
            let average = Insights.dailyAverage(expense: current.expense, month: month, today: ledger.today)
            return average > 0
                ? "Averaging \(CurrencyFormatter.formatRp(average)) a day. Switch units to feel what it means."
                : "Nothing spent yet this month. Switch units to feel what it means."
        case .mie:
            return loggedBowlPrice != nil
                ? "1 bowl = \(CurrencyFormatter.formatRp(bowlPrice)), your latest mie ayam price."
                : "1 bowl = \(CurrencyFormatter.formatRp(bowlPrice)), a typical price. Log “mie ayam” and Duit will use yours."
        case .hours:
            return hourPrice > 0
                ? "1 work hour = \(CurrencyFormatter.formatRp(hourPrice)) (salary ÷ \(Insights.workHoursPerMonth) hours)."
                : "Add your monthly salary in Settings to see money as work hours."
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            monthWindow
            budgetsWindow
            slicesWindow
            chartWindow
        }
    }

    // MARK: Month

    private var monthWindow: some View {
        RetroWindow(title: month.fullName, tint: Theme.titleColors[3], icon: PixelIconData.chart) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    LCDStatBox(caption: "Spent" + shownUnit.caption, value: lcd(current.expense))
                    LCDStatBox(caption: "Income" + shownUnit.caption, value: lcd(current.income))
                }
                RetroTabs(items: Insights.MoneyUnit.allCases, label: { $0.label }, selection: $unit)
                Text(unitNote)
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(14)
        }
    }

    // MARK: Budgets

    private var budgetLines: [BudgetLine] {
        BudgetLines.lines(
            limits: ledger.budgets.map { BudgetLimit(categoryID: $0.categoryID, amount: $0.amount) },
            categories: ledger.categories(of: .expense).map { (id: $0.id, name: $0.name) },
            spending: BudgetCalculator.spending(ledger.entries, in: month)
        )
    }

    private var budgetsWindow: some View {
        let lines = budgetLines
        return RetroWindow(title: "Budgets", tint: Theme.titleColors[2], icon: PixelIconData.panel) {
            if lines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("No budgets yet. Set your spending money, or a limit for a category like Food, and Duit shows how much is left.")
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)
                    Button("Set budgets", action: onGoSettings)
                        .buttonStyle(RetroButtonStyle(small: true))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            } else {
                VStack(spacing: 16) {
                    ForEach(lines) { line in budgetRow(line) }
                }
                .padding(14)
            }
        }
    }

    private func budgetRow(_ line: BudgetLine) -> some View {
        let p = line.progress
        let left = p.remaining >= 0 ? "\(compact(p.remaining)) left" : "\(compact(-p.remaining)) over"
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(line.label)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                BudgetStatusChip(status: p.status)
            }
            BudgetMeter(progress: p)
            HStack {
                Text("\(compact(p.spent)) of \(compact(p.limit))")
                Spacer(minLength: 4)
                Text(left)
            }
            .font(.plex(12))
            .foregroundStyle(Theme.ink2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.label) budget, \(p.status.label)")
        .accessibilityValue("\(p.percentUsed)% used. \(compact(p.spent)) of \(compact(p.limit)). \(left).")
    }

    // MARK: Where it went

    private var slicesWindow: some View {
        let slices = Insights.categoryBreakdown(ledger.entries, month: month)
        let biggest = max(1, slices.map(\.amount).max() ?? 1)
        return RetroWindow(title: "Where it went", tint: Theme.titleColors[0], icon: PixelIconData.cart) {
            if slices.isEmpty {
                Text("No spending logged in \(month.fullName) yet. Add an expense and it shows up here.")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                        sliceRow(slice, biggest: biggest)
                    }
                }
                .padding(14)
            }
        }
    }

    private func sliceRow(_ slice: Insights.CategorySlice, biggest: Int) -> some View {
        let amount = Insights.inUnit(slice.amount, unit: shownUnit, bowlPrice: bowlPrice, hourPrice: hourPrice)
        let share = Int((slice.share * 100).rounded())
        let fill = max(0.02, Double(slice.amount) / Double(biggest))
        return HStack(spacing: 10) {
            CategoryTile(category: ledger.category(id: slice.categoryID))
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(slice.name)
                        .font(.plex(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(amount)
                        .font(.plex(13, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    GeometryReader { proxy in
                        Theme.expenseBar
                            .frame(width: proxy.size.width * fill)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 10)
                    .retroSunk()
                    Text("\(share)%")
                        .font(.plex(12, .semibold))
                        .foregroundStyle(Theme.ink2)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slice.name), \(amount), \(share)% of spending")
    }

    // MARK: 6 months

    private var chartWindow: some View {
        let points = trend
        let selected = points.indices.contains(selectedColumn) ? points[selectedColumn] : current
        return RetroWindow(title: "6 months", tint: Theme.titleColors[1], icon: PixelIconData.chart) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    legendSwatch(Theme.incomeBar)
                    Text("Income")
                    Color.clear.frame(width: 10, height: 1)
                    legendSwatch(Theme.expenseBar)
                    Text("Spending")
                }
                .font(.plex(12))
                .foregroundStyle(Theme.ink2)
                .accessibilityHidden(true)

                TrendChart(points: points, selected: $selectedColumn)

                Text(Insights.statusLine(selected))
                    .font(.plex(12))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .retroSunk()
            }
            .padding(14)
        }
    }

    private func legendSwatch(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
    }
}

// MARK: - Prices

private struct PricesSection: View {
    let ledger: Ledger

    var body: some View {
        let result = PriceTracker.rows(ledger.entries, today: ledger.today)
        return RetroWindow(title: "Your Prices", tint: Theme.titleColors[3], icon: PixelIconData.cart) {
            VStack(alignment: .leading, spacing: 0) {
                if result.rows.isEmpty {
                    Text("Not enough repeated purchases yet.")
                        .font(.pixel(16))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("Your basket: \(result.basket > 0 ? "+" : "")\(result.basket)%")
                        .font(.pixel(20))
                        .foregroundStyle(result.basket > 0 ? Theme.negative : (result.basket < 0 ? Theme.positive : Theme.ink))
                }
                Text(result.rows.isEmpty
                    ? "Log the same thing a few times, like “mie ayam”, in different months. Duit reads the titles and tracks what it costs you."
                    : "Prices of things you buy again and again, read from your titles over 12 months. Log “mie ayam” a few times and watch it change.")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
                    .padding(.top, 4)
                if !result.rows.isEmpty {
                    VStack(spacing: 16) {
                        ForEach(result.rows, id: \.title) { row in priceRow(row) }
                    }
                    .padding(.top, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private func priceRow(_ row: PriceRow) -> some View {
        let category = ledger.category(named: row.categoryName, kind: .expense)
        let percent = "\(row.percent > 0 ? "+" : "")\(row.percent)%"
        let range = "\(CurrencyFormatter.formatNumber(row.first)) → \(CurrencyFormatter.formatNumber(row.last)) since \(row.since.shortName) \(row.since.year)"
        return HStack(spacing: 10) {
            CategoryTile(category: category)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.plex(14, .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(range)
                    .font(.plex(11.5))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(row.barHeights.enumerated()), id: \.offset) { _, h in
                    Rectangle().fill(Theme.expenseBar).frame(width: 5, height: CGFloat(h))
                }
            }
            .frame(height: 22, alignment: .bottom)
            .accessibilityHidden(true)
            Text(percent)
                .font(.plex(13, .bold))
                .foregroundStyle(row.percent > 0 ? Theme.negative : (row.percent < 0 ? Theme.positive : Theme.ink2))
                .frame(width: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title), \(percent)")
        .accessibilityValue(range)
    }
}

// MARK: - Habits

private struct HabitsSection: View {
    let ledger: Ledger

    @State private var openID: String?
    @State private var frequency: [String: Int] = [:]

    private var bowlPrice: Int { PriceTracker.latestPrice(containing: "mie ayam", entries: ledger.entries) ?? assumedBowlPrice }

    var body: some View {
        VStack(spacing: 18) {
            machineWindow
            worthWindow
        }
    }

    // MARK: Time Machine

    private var machineWindow: some View {
        let habits = HabitFinder.habits(ledger.entries, today: ledger.today)
        return RetroWindow(title: "Habit Time Machine", tint: Theme.titleColors[2], icon: PixelIconData.hourglass) {
            if habits.isEmpty {
                Text("No habits found yet. When you buy the same thing four or more times in eight weeks, it shows up here, and you can see what a year of it costs.")
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        if index > 0 { DottedDivider() }
                        habitRow(habit)
                    }
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        let open = openID == habit.id
        return VStack(spacing: 0) {
            Button { openID = open ? nil : habit.id } label: {
                HStack(spacing: 10) {
                    CategoryTile(category: ledger.category(named: habit.categoryName, kind: .expense))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(habit.title)
                            .font(.plex(14, .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("\(habit.perWeek)× a week · \(CurrencyFormatter.formatNumber(habit.price)) each")
                            .font(.plex(11.5))
                            .foregroundStyle(Theme.ink2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(compact(habit.yearly))/yr")
                        .font(.plex(14, .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minHeight: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressStyle())
            .accessibilityHint(open ? "Hides the what-if slider" : "Shows a what-if slider")

            if open { whatIf(habit) }
        }
    }

    private func whatIf(_ habit: Habit) -> some View {
        let freq = frequency[habit.id] ?? habit.perWeek
        let projection = HabitFinder.project(habit, perWeek: freq)
        let result: String
        if freq == habit.perWeek {
            result = "Drag the slider to change how often."
        } else if projection.saved > 0 {
            result = "At \(freq)× a week: \(compact(projection.yearNew))/yr. Saves \(compact(projection.saved)) a year."
        } else {
            result = "At \(freq)× a week: \(compact(-projection.saved)) more a year."
        }
        let bowls = Insights.inUnit(projection.saved, unit: .mie, bowlPrice: bowlPrice, hourPrice: 0)
        let goal = projection.saved > 0
            ? "That is \(bowls) of mie ayam, or a Bali trip (\(compact(HabitFinder.goal))) in \(projection.monthsToGoal) \(projection.monthsToGoal == 1 ? "month" : "months")."
            : ""
        return VStack(alignment: .leading, spacing: 4) {
            (Text("Per week: ").font(.plex(13)) + Text("\(freq)×").font(.plex(13, .bold)))
                .foregroundStyle(Theme.ink)
            RetroStepSlider(
                value: Binding(get: { freq }, set: { frequency[habit.id] = $0 }),
                range: 0...7,
                accessibilityLabel: "How many times a week for \(habit.title)"
            )
            Text(result)
                .font(.plex(13, .semibold))
                .foregroundStyle(Theme.ink)
            if !goal.isEmpty {
                Text(goal)
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .padding(.leading, 58)
        .padding(.trailing, 14)
        .padding(.bottom, 14)
        .padding(.top, 2)
    }

    // MARK: Worth it?

    private var worthWindow: some View {
        let report = WorthIt.report(ledger.entries)
        let note: String
        if !report.regretTitles.isEmpty {
            note = "Nyesel list: \(report.regretTitles.joined(separator: ", ")). Next time, sleep on purchases like these."
        } else if report.anyRated {
            note = "No regrets so far. Nice."
        } else {
            note = "Rate purchases in To do on the Today screen to build this report."
        }
        return RetroWindow(title: "Worth it?", tint: Theme.titleColors[0], icon: PixelIconData.star) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    LCDStatBox(caption: "Worth it", value: compact(report.worthTotal))
                    LCDStatBox(caption: "Nyesel", value: compact(report.regretTotal))
                }
                Text(note)
                    .font(.plex(12.5))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(14)
        }
    }
}
