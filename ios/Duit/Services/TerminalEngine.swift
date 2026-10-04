import Foundation

/// Everything the Terminal needs to answer a question about the user's month.
struct TerminalContext {
    var monthName: String
    var totalSpent: Int
    /// Spending this month by category name.
    var spentByCategory: [String: Int]
    var categoryNames: [String]
    /// This month's expenses, one per transaction.
    var expenses: [(title: String, amount: Int)]
    /// Lines for "sisa" (e.g. "Rp 68.357 a day for 7 days (battery 4%).").
    var allowanceLines: [String]
    /// Lines for "inflasi".
    var inflationLines: [String]
}

/// The Duit Terminal's question side — a port of `isQuestion` / `runQuery`
/// in design/prototype/Main.dc.html. Lines are plain text for a monospace
/// display, so they're padded with spaces and `#` bars.
enum TerminalEngine {
    private static let filler: Set<String> = [
        "berapa", "brp", "total", "habis", "pengeluaran", "spent", "how", "much", "buat", "untuk", "bulan",
        "ini", "minggu", "saya", "aku", "gue", "gw", "for", "on", "this", "month", "di", "sih", "ya", "is", "my",
    ]

    static func isQuestion(_ text: String) -> Bool {
        let x = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if x == "?" || x.hasSuffix("?") { return true }
        if x.range(of: #"\bvs\b"#, options: .regularExpression) != nil { return true }
        let starters = #"^(help|berapa|brp|total|how|terbesar|biggest|top|sisa|harian|uang harian|inflasi|harga)\b"#
        return x.range(of: starters, options: .regularExpression) != nil
    }

    static func answer(_ input: String, context: TerminalContext) -> [String] {
        var x = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while x.hasSuffix("?") { x.removeLast() }
        x = x.trimmingCharacters(in: .whitespaces)

        if x == "help" || x.isEmpty {
            return [
                "LOG   es teh goceng · mie ayam 22rb kemarin",
                "      kos 3,5jt bca · topup gopay 100rb · gaji 16,5jt",
                "ASK   berapa kopi? · grab vs gojek · terbesar",
                "      sisa · inflasi · help",
            ]
        }

        if x.range(of: #"\bvs\b"#, options: .regularExpression) != nil {
            let marker = "\u{1F}"
            let parts = x.replacingOccurrences(of: #"\bvs\b"#, with: marker, options: .regularExpression)
                .components(separatedBy: marker)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(3)
            let results = parts.map { part in
                sumTerm(part, context: context, preferTitles: true) ?? (label: SlangVocabulary.titleCase(part), amount: 0)
            }
            let top = max(1, results.map { $0.amount }.max() ?? 1)
            return results.map { r in
                pad(r.label, 12) + " " + pad(bars(r.amount, max: top), 14) + " " + CurrencyFormatter.formatRpCompact(r.amount)
            }
        }

        if x.range(of: "^(terbesar|biggest|top)", options: .regularExpression) != nil {
            return context.expenses
                .sorted { $0.amount > $1.amount }
                .prefix(3)
                .enumerated()
                .map { index, e in "\(index + 1). \(pad(e.title, 14)) \(CurrencyFormatter.formatRp(e.amount))" }
        }

        if x.range(of: "^(sisa|harian|uang harian)", options: .regularExpression) != nil {
            return context.allowanceLines
        }
        if x.range(of: "^(inflasi|harga)", options: .regularExpression) != nil {
            return context.inflationLines
        }

        let term = x.split(separator: " ").map(String.init).filter { !filler.contains($0) }.joined(separator: " ")
        if term.isEmpty {
            return ["\(context.monthName) so far: \(CurrencyFormatter.formatRp(context.totalSpent)) spent."]
        }
        guard let r = sumTerm(term, context: context, preferTitles: false) else {
            return ["Nothing found for \"\(term)\" this month."]
        }
        return ["\(r.label) in \(context.monthName): \(CurrencyFormatter.formatRp(r.amount)) (\(percent(r.amount, of: context.totalSpent))% of spending)"]
    }

    /// A match for a word: a category's total, or the sum of expenses whose title contains it.
    private static func sumTerm(_ term: String, context: TerminalContext, preferTitles: Bool) -> (label: String, amount: Int)? {
        let t = term.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return nil }
        let titled = context.expenses.filter { $0.title.lowercased().contains(t) }
        let titleSum = titled.reduce(0) { $0 + $1.amount }
        var category = SlangVocabulary.categoryWords[t]
        if category == nil { category = context.categoryNames.first { $0.lowercased().contains(t) } }
        let categorySpent = category.flatMap { context.spentByCategory[$0] } ?? 0
        if !preferTitles, let category, categorySpent > 0 { return (category, categorySpent) }
        if !titled.isEmpty { return ("\(SlangVocabulary.titleCase(t)) (\(titled.count)x)", titleSum) }
        if let category, categorySpent > 0 { return (category, categorySpent) }
        return nil
    }

    static func pad(_ s: String, _ n: Int) -> String {
        if s.count > n { return String(s.prefix(n - 1)) + "~" }
        return s + String(repeating: " ", count: n - s.count)
    }

    static func bars(_ v: Int, max top: Int) -> String {
        guard top > 0 else { return "" }
        return String(repeating: "#", count: max(1, Int((Double(v) / Double(top) * 14).rounded())))
    }

    /// 12.5 → "12,5", 12 → "12" (Indonesian decimal comma).
    private static func percent(_ part: Int, of whole: Int) -> String {
        guard whole > 0 else { return "0" }
        let value = (Double(part) / Double(whole) * 1000).rounded() / 10
        let f = NumberFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
}
