import Foundation

/// Reading money out of the cells of a bank statement: Indonesian
/// (`1.234.567,89`) or English (`1,234,567.89`) number habits, a sign or a
/// DB / CR marker for the direction, and an `Rp` / `IDR` label.
enum ImportAmount {
    enum Direction: Equatable { case moneyOut, moneyIn }

    struct Parsed: Equatable {
        /// Whole rupiah, never negative; the direction is separate.
        var value: Int
        /// What the cell itself says (a minus, brackets, DB, CR…); nil when it says nothing.
        var direction: Direction?
    }

    private static let outMarkers: Set<String> = ["db", "dr", "d", "dbt", "debit", "debet"]
    private static let inMarkers: Set<String> = ["cr", "k", "c", "kr", "credit", "kredit"]

    static func parse(_ raw: String) -> Parsed? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        var direction: Direction?
        if text.hasPrefix("-") || text.hasPrefix("\u{2212}") || text.hasSuffix("-") {
            direction = .moneyOut
        } else if text.hasPrefix("(") && text.hasSuffix(")") {
            direction = .moneyOut
        } else if text.hasPrefix("+") {
            direction = .moneyIn
        }

        // Digits and separators make the number; runs of letters are labels
        // ("Rp", "IDR") or markers ("DB", "CR").
        var number = ""
        var word = ""
        var words: [String] = []
        for ch in text {
            if ch.isASCII && ch.isNumber || ch == "." || ch == "," {
                number.append(ch)
                if !word.isEmpty { words.append(word); word = "" }
            } else if ch.isLetter {
                word.append(ch)
            } else if !word.isEmpty {
                words.append(word)
                word = ""
            }
        }
        if !word.isEmpty { words.append(word) }

        for w in words.map({ $0.lowercased() }) {
            if outMarkers.contains(w) { direction = .moneyOut }
            if inMarkers.contains(w) { direction = .moneyIn }
        }
        guard let value = wholeRupiah(number) else { return nil }
        return Parsed(value: value, direction: direction)
    }

    /// "1.234.567,89" → 1234568, "150.000" → 150000, "1500000.00" → 1500000.
    /// With both marks, the one that comes last is the decimal mark. With one
    /// mark that occurs once, exactly three digits after it read as thousands
    /// (rupiah has no cents in practice: "150.000"), anything else as decimals.
    static func wholeRupiah(_ number: String) -> Int? {
        guard number.contains(where: { $0.isNumber }) else { return nil }
        let dot = number.lastIndex(of: ".")
        let comma = number.lastIndex(of: ",")
        var decimalMark: Character?
        switch (dot, comma) {
        case let (d?, c?):
            decimalMark = d > c ? "." : ","
        case let (d?, nil):
            decimalMark = isDecimal(number, mark: ".", at: d) ? "." : nil
        case let (nil, c?):
            decimalMark = isDecimal(number, mark: ",", at: c) ? "," : nil
        case (nil, nil):
            decimalMark = nil
        }

        var whole = number
        var fraction = ""
        if let mark = decimalMark, let at = number.lastIndex(of: mark) {
            whole = String(number[..<at])
            fraction = String(number[number.index(after: at)...])
        }
        let digits = whole.filter { $0.isNumber }
        guard digits.count <= 15 else { return nil }
        var value = digits.isEmpty ? 0 : (Int(digits) ?? -1)
        guard value >= 0 else { return nil }
        if let first = fraction.first(where: { $0.isNumber }), first >= "5" { value += 1 }
        return value
    }

    /// Whether a mark that appears once is a decimal point (see `wholeRupiah`).
    private static func isDecimal(_ number: String, mark: Character, at index: String.Index) -> Bool {
        guard number.filter({ $0 == mark }).count == 1 else { return false } // 1.234.567 → thousands
        let before = number[..<index].filter { $0.isNumber }
        let after = number[number.index(after: index)...].filter { $0.isNumber }
        if after.count == 3 && !before.isEmpty && before != "0" { return false }
        return true
    }
}

/// Reading dates out of the cells of a bank statement. Day-first (`31/12/2025`)
/// is the Indonesian habit; month names in English and Indonesian work
/// (`1 Okt 2025`, `01-Oct-25`); a time after the date is ignored.
enum ImportDate {
    enum Order: Equatable { case dayFirst, monthFirst }

    private static let months: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "mei": 5, "jun": 6, "jul": 7,
        "aug": 8, "agu": 8, "agt": 8, "ags": 8, "sep": 9, "oct": 10, "okt": 10,
        "nov": 11, "nop": 11, "dec": 12, "des": 12,
    ]

    private struct Token {
        let text: String
        let isNumber: Bool
        /// The separator right before it ("/", "-", " "…), "" for the first.
        let before: Character?
    }

    private static func tokens(_ raw: String) -> [Token] {
        var out: [Token] = []
        var run = ""
        var runIsNumber = false
        var separator: Character?
        var pending: Character?
        func flush() {
            guard !run.isEmpty else { return }
            out.append(Token(text: run, isNumber: runIsNumber, before: separator))
            run = ""
            separator = nil
        }
        for ch in raw {
            if ch.isASCII && ch.isNumber {
                if !run.isEmpty && !runIsNumber { flush() }
                if run.isEmpty { runIsNumber = true; separator = pending }
                run.append(ch)
                pending = nil
            } else if ch.isLetter {
                if !run.isEmpty && runIsNumber { flush() }
                if run.isEmpty { runIsNumber = false; separator = pending }
                run.append(ch)
                pending = nil
            } else {
                flush()
                pending = ch
            }
        }
        flush()
        return out
    }

    private static func monthNumber(named word: String) -> Int? {
        let w = word.lowercased()
        if let m = months[w] { return m }
        return w.count > 3 ? months[String(w.prefix(3))] : nil
    }

    /// Day-first unless the file proves otherwise: a first number above 12 means
    /// day-first, a second number above 12 means month-first.
    static func detectOrder(_ cells: [String]) -> Order {
        var dayFirst = false
        var monthFirst = false
        for cell in cells {
            let t = tokens(cell)
            guard t.count >= 2, t[0].isNumber, t[1].isNumber, t[0].text.count <= 2, t[1].text.count <= 2,
                  let a = Int(t[0].text), let b = Int(t[1].text) else { continue }
            if a > 12 { dayFirst = true }
            if b > 12 { monthFirst = true }
        }
        return monthFirst && !dayFirst ? .monthFirst : .dayFirst
    }

    /// A calendar day (no time of day), or nil if the text isn't a date with a year.
    static func parse(_ raw: String, order: Order = .dayFirst) -> Date? {
        var list = tokens(raw)
        // Skip a weekday name or other words in front ("Wed, 1 Oct 2025").
        while let first = list.first, !first.isNumber, monthNumber(named: first.text) == nil {
            list.removeFirst()
        }
        guard let (year, month, day) = yearMonthDay(list, raw: raw, order: order),
              (1...12).contains(month), (1...31).contains(day), (1900...2100).contains(year) else { return nil }
        let date = DateHelpers.date(year: year, month: month, day: day)
        // 30 Feb would quietly become 2 Mar; refuse it instead.
        guard DateHelpers.calendar.component(.day, from: date) == day,
              DateHelpers.calendar.component(.month, from: date) == month else { return nil }
        return date
    }

    private static func yearMonthDay(_ list: [Token], raw: String, order: Order) -> (Int, Int, Int)? {
        guard let a = list.first else { return nil }
        // 20251001
        if a.isNumber, a.text.count == 8,
           let y = Int(a.text.prefix(4)), let m = Int(a.text.dropFirst(4).prefix(2)), let d = Int(a.text.suffix(2)) {
            return (y, m, d)
        }
        guard list.count >= 3 else { return nil }
        let b = list[1]
        let c = list[2]

        // 2025-10-01, 2025/10/01, 2025 Okt 1
        if a.isNumber && a.text.count == 4 {
            guard let y = Int(a.text), c.isNumber, let d = Int(c.text),
                  let m = b.isNumber ? Int(b.text) : monthNumber(named: b.text) else { return nil }
            return (y, m, d)
        }
        if a.isNumber && a.text.count <= 2, let first = Int(a.text) {
            if !b.isNumber {
                // 1 Okt 2025, 01-Oct-25
                guard let m = monthNumber(named: b.text), let y = yearValue(c, mayBeTime: false, raw: raw, middle: b) else { return nil }
                return (y, m, first)
            }
            // 01/10/2025 — but "01/10 14:30" has no year, only a time.
            guard let second = Int(b.text), let y = yearValue(c, mayBeTime: true, raw: raw, middle: b) else { return nil }
            return order == .dayFirst ? (y, second, first) : (y, first, second)
        }
        // Oct 1, 2025
        if !a.isNumber, let m = monthNumber(named: a.text), b.isNumber, let d = Int(b.text),
           let y = yearValue(c, mayBeTime: false, raw: raw, middle: b) {
            return (y, m, d)
        }
        return nil
    }

    private static func yearValue(_ token: Token, mayBeTime: Bool, raw: String, middle: Token) -> Int? {
        guard token.isNumber else { return nil }
        if token.text.count == 4 { return Int(token.text) }
        guard token.text.count == 2, let yy = Int(token.text) else { return nil }
        // "01/10 14:30": the "14" after a space is the hour, not a year.
        if mayBeTime, raw.contains(":"), token.before != middle.before { return nil }
        return yy >= 70 ? 1900 + yy : 2000 + yy
    }
}
