import Foundation

/// Insights math — a port of src/domain/insights.ts (tested in
/// finance.test.ts) plus the retro prototype's chart scale and
/// "feel what it means" units (mie ayam bowls, work hours).
enum Insights {
    // MARK: Category breakdown

    struct CategorySlice: Equatable {
        let categoryID: UUID?
        let name: String
        let amount: Int
        let count: Int
        /// 0...1 share of the month's total for this kind.
        let share: Double
        /// Same category, previous month.
        let previous: Int
    }

    static func categoryBreakdown(_ entries: [Entry], month: MonthKey, kind: TransactionType = .expense) -> [CategorySlice] {
        struct Running { var name: String; var amount = 0; var count = 0 }
        let previousMonth = month.shifted(by: -1)
        var current: [UUID?: Running] = [:]
        var firstSeen: [UUID?] = []
        var previous: [UUID?: Int] = [:]
        var total = 0
        for t in entries where t.type == kind {
            let m = MonthKey(t.date)
            if m == month {
                if current[t.categoryID] == nil {
                    firstSeen.append(t.categoryID)
                    current[t.categoryID] = Running(name: t.categoryName ?? "Uncategorized")
                }
                current[t.categoryID]?.amount += t.amount
                current[t.categoryID]?.count += 1
                total += t.amount
            } else if m == previousMonth {
                previous[t.categoryID, default: 0] += t.amount
            }
        }
        let slices = firstSeen.compactMap { id -> CategorySlice? in
            guard let r = current[id] else { return nil }
            return CategorySlice(
                categoryID: id,
                name: r.name,
                amount: r.amount,
                count: r.count,
                share: total > 0 ? Double(r.amount) / Double(total) : 0,
                previous: previous[id] ?? 0
            )
        }
        // Biggest first; ties keep the order they first appeared.
        return slices.enumerated()
            .sorted { $0.element.amount != $1.element.amount ? $0.element.amount > $1.element.amount : $0.offset < $1.offset }
            .map { $0.element }
    }

    // MARK: Trend

    struct TrendPoint: Equatable {
        let month: MonthKey
        var income: Int
        var expense: Int
    }

    /// `months` points ending at `endMonth`, oldest first. Transfers excluded.
    static func monthlyTrend(_ entries: [Entry], endMonth: MonthKey, months: Int = 6) -> [TrendPoint] {
        var points: [MonthKey: TrendPoint] = [:]
        var order: [MonthKey] = []
        for i in stride(from: months - 1, through: 0, by: -1) {
            let m = endMonth.shifted(by: -i)
            points[m] = TrendPoint(month: m, income: 0, expense: 0)
            order.append(m)
        }
        for t in entries where t.type != .transfer {
            let m = MonthKey(t.date)
            guard points[m] != nil else { continue }
            if t.type == .income { points[m]?.income += t.amount } else { points[m]?.expense += t.amount }
        }
        return order.compactMap { points[$0] }
    }

    /// Average spend per elapsed day (the whole month if it's in the past).
    static func dailyAverage(expense: Int, month: MonthKey, today: Date) -> Int {
        let current = MonthKey(today)
        let elapsed: Int
        if current == month {
            elapsed = DateHelpers.day(of: today)
        } else if current < month {
            elapsed = 0
        } else {
            elapsed = month.dayCount
        }
        return elapsed > 0 ? Int((Double(expense) / Double(elapsed)).rounded()) : 0
    }

    // MARK: Chart scale

    /// A tidy axis maximum at or above `v` (1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10 × 10ⁿ).
    static func niceMax(_ v: Double) -> Double {
        if v <= 0 { return 1 }
        let e = pow(10, floor(log10(v)))
        let f = v / e
        for step in [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10] where f <= step {
            return step * e
        }
        return 10 * e
    }

    /// The chart's top edge: a tidy number above the tallest bar, or Rp 1 jt
    /// when there's nothing to draw yet (so the axis never reads "Rp 1").
    static func chartMax(_ points: [TrendPoint]) -> Double {
        let peak = points.map { max($0.income, $0.expense) }.max() ?? 0
        return peak > 0 ? niceMax(Double(peak)) : 1_000_000
    }

    /// The line under the chart for the selected month:
    /// "September · in Rp 17,5 jt · out Rp 12 jt · net +5,5 jt".
    static func statusLine(_ point: TrendPoint) -> String {
        let net = point.income - point.expense
        let netText = (net > 0 ? "+" : "") + CurrencyFormatter.formatCompact(net)
        return "\(point.month.fullName) · in \(CurrencyFormatter.formatRpCompact(point.income)) · out \(CurrencyFormatter.formatRpCompact(point.expense)) · net \(netText)"
    }

    // MARK: Units — "feel what it means"

    enum MoneyUnit: String, CaseIterable, Identifiable {
        case rupiah, mie, hours
        var id: String { rawValue }
        var label: String {
            switch self {
            case .rupiah: "Rupiah"
            case .mie: "Mie ayam"
            case .hours: "Work hrs"
            }
        }
        var caption: String {
            switch self {
            case .rupiah: ""
            case .mie: " · bowls"
            case .hours: " · work hrs"
            }
        }
    }

    /// Working hours in a month, as the prototype assumes (salary ÷ 173).
    static let workHoursPerMonth = 173

    static func hourPrice(salary: Int) -> Int {
        salary > 0 ? Int((Double(salary) / Double(workHoursPerMonth)).rounded()) : 0
    }

    private static let quantityFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.roundingMode = .halfUp
        return f
    }()

    /// 12.4 → "12", 3.26 → "3,3" (whole numbers from 10 up, one decimal below).
    static func formatQuantity(_ v: Double) -> String {
        let shown = v >= 10 ? v.rounded() : (v * 10).rounded() / 10
        return quantityFormatter.string(from: NSNumber(value: shown)) ?? "0"
    }

    /// Full text with its unit: "12 bowls", "3,3 work hrs", or "150.000".
    static func inUnit(_ n: Int, unit: MoneyUnit, bowlPrice: Int, hourPrice: Int) -> String {
        switch unit {
        case .mie:
            guard bowlPrice > 0 else { return CurrencyFormatter.formatNumber(n) }
            let bowls = Double(n) / Double(bowlPrice)
            return formatQuantity(bowls) + (bowls == 1 ? " bowl" : " bowls")
        case .hours:
            guard hourPrice > 0 else { return CurrencyFormatter.formatNumber(n) }
            return formatQuantity(Double(n) / Double(hourPrice)) + " work hrs"
        case .rupiah:
            return CurrencyFormatter.formatNumber(n)
        }
    }

    /// The short form for the big LCD boxes: "Rp 12 jt", "12", "3,3".
    static func lcdText(_ n: Int, unit: MoneyUnit, bowlPrice: Int, hourPrice: Int) -> String {
        switch unit {
        case .rupiah:
            return CurrencyFormatter.formatRpCompact(n)
        case .mie:
            return bowlPrice > 0 ? formatQuantity(Double(n) / Double(bowlPrice)) : CurrencyFormatter.formatNumber(n)
        case .hours:
            return hourPrice > 0 ? formatQuantity(Double(n) / Double(hourPrice)) : CurrencyFormatter.formatNumber(n)
        }
    }
}
