import Foundation

/// IDR money helpers — a direct port of src/lib/money.ts. Amounts are
/// always positive integer rupiah; the transaction type carries the sign.
/// See DuitTests/CurrencyFormatterTests.swift, ported from money.test.ts.
enum CurrencyFormatter {
    /// < 1 trillion rupiah, matches src/lib/money.ts MAX_AMOUNT.
    static let maxAmount = 999_999_999_999

    /// Typographic minus, same width as plus.
    private static let minus = "\u{2212}"

    private static let plain: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        // Match Intl's round-half-away-from-zero (default .roundHalfEven
        // would turn 1.25 into 1.2, not the 1.3 the web app's tests expect).
        f.roundingMode = .halfUp
        return f
    }()

    /// 150000 → "150.000"
    static func formatNumber(_ n: Int) -> String {
        plain.string(from: NSNumber(value: abs(n))) ?? "0"
    }

    /// 150000 → "Rp 150.000", -150000 → "−Rp 150.000"
    static func formatRp(_ n: Int) -> String {
        let s = "Rp \(formatNumber(n))"
        return n < 0 ? minus + s : s
    }

    /// 1250000 → "1,3 jt", 150000 → "150 rb" (Indonesian compact units).
    static func formatCompact(_ n: Int) -> String {
        let v = abs(n)
        let s: String
        switch v {
        case 1_000_000_000...:
            s = oneDecimalString(Double(v) / 1_000_000_000) + " M"
        case 1_000_000...:
            s = oneDecimalString(Double(v) / 1_000_000) + " jt"
        case 1_000...:
            s = oneDecimalString(Double(v) / 1_000) + " rb"
        default:
            s = formatNumber(v)
        }
        return n < 0 ? minus + s : s
    }

    /// "Rp 1,3 jt"
    static func formatRpCompact(_ n: Int) -> String {
        let s = "Rp \(formatCompact(abs(n)))"
        return n < 0 ? minus + s : s
    }

    /// Signed display for a flow: +8.500.000 / −45.000
    static func formatSigned(_ n: Int) -> String {
        if n == 0 { return "0" }
        return (n > 0 ? "+" : minus) + formatNumber(n)
    }

    /// Keep digits only and clamp: "Rp 12.500" → 12500
    static func parseAmount(_ input: String) -> Int {
        let digits = input.filter(\.isNumber)
        guard !digits.isEmpty, let n = Int(digits) else { return 0 }
        return min(n, maxAmount)
    }

    /// Parse a signed amount (for opening balances, once Accounts exists):
    /// "-1.500.000" → -1500000
    static func parseSignedAmount(_ input: String) -> Int {
        let negative = input.trimmingCharacters(in: .whitespaces).first.map { $0 == "-" || $0 == "\u{2212}" } ?? false
        let n = parseAmount(input)
        return negative ? -n : n
    }

    private static func oneDecimalString(_ v: Double) -> String {
        oneDecimal.string(from: NSNumber(value: v)) ?? "0"
    }
}
