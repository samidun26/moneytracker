import Foundation

/// What the Duit Terminal understood from a line like "mie ayam goceng" or
/// "bensin ceban kemarin". Resolve `categoryName` against the user's real
/// categories (by name and kind) before saving.
struct ParsedEntry: Equatable {
    var ok: Bool
    var amount: Int
    var type: TransactionType
    var title: String
    /// A default category name, e.g. "Food & Drinks". nil for transfers.
    var categoryName: String?
    var accountID: UUID?
    /// Transfers only.
    var fromAccountID: UUID?
    var toAccountID: UUID?
    /// 0 = today, -1 = yesterday.
    var dayOffset: Int
    /// Small explanations shown under the preview ("goceng = Rp 5.000").
    var notes: [String]
}

struct ParseContext {
    var accounts: [AccountRef]
    /// Past entries, **newest first**, used to reuse a known title's category and account.
    var history: [Entry]
    var defaultExpenseAccountID: UUID?
    var defaultIncomeAccountID: UUID?
}

/// The offline Indonesian "slang" parser — a line-by-line port of
/// `parseEntry` in design/prototype/Main.dc.html. It reads amounts written as
/// "18rb", "25.000", "3,5jt", slang ("goceng", "ceban") or words ("dua puluh
/// lima ribu"), plus an optional day ("kemarin"), account ("gopay") and
/// category hints.
enum SlangParser {
    private static let numberPattern = try! NSRegularExpression(pattern: #"^(\d+(?:[.,]\d+)*)(rb|ribu|rebu|k|jt|juta)?$"#)
    private static let decimalPattern = try! NSRegularExpression(pattern: #"^\d+[.,]\d{1,2}$"#)

    private static func firstMatch(_ regex: NSRegularExpression, in s: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
    }

    static func parse(_ input: String, context: ParseContext) -> ParsedEntry {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "hari ini", with: "tadi")
            .replacingOccurrences(of: "top up", with: "topup")
        let toks = raw.split(whereSeparator: \.isWhitespace).map(String.init)

        var used = Set<Int>()
        var notes: [String] = []
        var total = 0.0
        var cur = 0.0
        var last = 0.0
        var seen = false
        var pending: [Int] = []

        // A run of number words only counts if it adds up to 100 or more;
        // otherwise those words go back to being part of the title.
        func flush() {
            if cur >= 100 {
                total += cur
                seen = true
            } else {
                for k in pending { used.remove(k) }
            }
            cur = 0
            last = 0
            pending = []
        }

        var i = 0
        while i < toks.count {
            defer { i += 1 }
            let w = toks[i]

            if let slangValue = SlangVocabulary.slang[w] {
                flush()
                var v = slangValue
                if v < 1000 {
                    notes.append("\(w) read as Rp \(CurrencyFormatter.formatNumber(v * 1000))")
                    v *= 1000
                } else {
                    notes.append("\(w) = Rp \(CurrencyFormatter.formatNumber(v))")
                }
                total += Double(v)
                seen = true
                used.insert(i)
                continue
            }

            if let m = firstMatch(numberPattern, in: w), let digitsRange = Range(m.range(at: 1), in: w) {
                flush()
                let digits = String(w[digitsRange])
                var suffix = ""
                if m.range(at: 2).location != NSNotFound, let r = Range(m.range(at: 2), in: w) { suffix = String(w[r]) }
                if suffix.isEmpty, i + 1 < toks.count {
                    let next = toks[i + 1]
                    if SlangVocabulary.thousand.contains(next) || SlangVocabulary.million.contains(next) {
                        suffix = next
                        used.insert(i + 1)
                    }
                }
                let isDecimal = firstMatch(decimalPattern, in: digits) != nil
                let base: Double
                if isDecimal {
                    base = Double(digits.replacingOccurrences(of: ",", with: ".")) ?? 0
                } else {
                    base = Double(digits.filter { $0 != "." && $0 != "," }) ?? 0
                }
                let v: Double
                if SlangVocabulary.million.contains(suffix) {
                    v = base * 1e6
                } else if SlangVocabulary.thousand.contains(suffix) {
                    v = base * 1000
                } else {
                    v = base
                }
                total += v.rounded()
                seen = true
                used.insert(i)
                if used.contains(i + 1) { i += 1 }
                continue
            }

            if let n = SlangVocabulary.numberWords[w] {
                cur += n; last = n; used.insert(i); pending.append(i); continue
            }
            if w == "seratus" {
                cur += 100; last = 0; used.insert(i); pending.append(i); continue
            }
            if w == "belas", !pending.isEmpty {
                cur += 10; last = 0; used.insert(i); pending.append(i); continue
            }
            if w == "puluh", !pending.isEmpty {
                cur = cur - last + last * 10; last = 0; used.insert(i); pending.append(i); continue
            }
            if w == "ratus", !pending.isEmpty {
                cur = cur - last + last * 100; last = 0; used.insert(i); pending.append(i); continue
            }
            if w == "seribu" {
                flush(); total += 1000; seen = true; used.insert(i); continue
            }
            if w == "sejuta" {
                flush(); total += 1e6; seen = true; used.insert(i); continue
            }
            if SlangVocabulary.thousand.contains(w), !pending.isEmpty {
                total += cur * 1000; seen = true; used.insert(i); cur = 0; last = 0; pending = []; continue
            }
            if SlangVocabulary.million.contains(w), !pending.isEmpty {
                total += cur * 1e6; seen = true; used.insert(i); cur = 0; last = 0; pending = []; continue
            }
            flush()
        }
        flush()

        // Second pass: what's left over describes the entry.
        var dayOffset = 0
        var account: UUID?
        var type = TransactionType.expense
        var incomeCategory: String?
        var topup = false
        var words: [String] = []
        for (index, w) in toks.enumerated() {
            if used.contains(index) { continue }
            if let d = SlangVocabulary.dayWords[w] { dayOffset = d; continue }
            if let id = accountID(for: w, in: context.accounts) { account = id; continue }
            if w == "topup" || w == "isi" { topup = true; continue }
            if SlangVocabulary.stopWords.contains(w) { continue }
            if let incomeName = SlangVocabulary.incomeWords[w] {
                type = .income
                incomeCategory = incomeCategory ?? incomeName
            }
            words.append(w)
        }

        var title = SlangVocabulary.titleCase(words.joined(separator: " "))
        let amount = Int(total.rounded())

        if topup {
            return parseTopup(amount: amount, seen: seen, account: account, dayOffset: dayOffset, notes: notes, context: context)
        }

        var category: String?
        if let hit = context.history.first(where: { $0.type != .transfer && !$0.title.isEmpty && $0.title.lowercased() == title.lowercased() }) {
            title = hit.title
            category = hit.categoryName
            type = hit.type
            if account == nil { account = hit.accountID }
            notes.append("Matched your past \"\(hit.title)\"")
        }
        if category == nil, type == .income { category = incomeCategory ?? "Other" }
        if category == nil {
            category = words.lazy.compactMap { SlangVocabulary.categoryWords[$0] }.first ?? "Other"
        }
        if account == nil { account = type == .income ? context.defaultIncomeAccountID : context.defaultExpenseAccountID }
        if title.isEmpty { title = category ?? "Other" }

        return ParsedEntry(
            ok: seen && amount > 0,
            amount: amount,
            type: type,
            title: title,
            categoryName: category,
            accountID: account,
            fromAccountID: nil,
            toAccountID: nil,
            dayOffset: dayOffset,
            notes: notes
        )
    }

    /// "topup gopay 100rb" moves money from a bank (or cash) into the e-wallet.
    private static func parseTopup(amount: Int, seen: Bool, account: UUID?, dayOffset: Int, notes: [String], context: ParseContext) -> ParsedEntry {
        let accounts = context.accounts.filter { !$0.archived }
        var target: AccountRef?
        if let account { target = accounts.first { $0.id == account } }
        if target == nil { target = accounts.first { $0.kind == .ewallet } }
        var source: AccountRef?
        if let t = target {
            source = accounts.first { $0.kind == .bank && $0.id != t.id }
            if source == nil { source = accounts.first { $0.kind == .cash && $0.id != t.id } }
            if source == nil { source = accounts.first { $0.id != t.id } }
        }
        var notes = notes
        if target == nil || source == nil { notes.append("Top up needs two wallets, like a bank and an e-wallet.") }
        return ParsedEntry(
            ok: seen && amount > 0 && target != nil && source != nil,
            amount: amount,
            type: .transfer,
            title: "Top up \(target?.name ?? "wallet")",
            categoryName: nil,
            accountID: target?.id,
            fromAccountID: source?.id,
            toAccountID: target?.id,
            dayOffset: dayOffset,
            notes: notes
        )
    }

    /// A word that names one of the user's accounts ("bca"), or a kind of
    /// account ("gopay" → their first e-wallet). Account names win.
    static func accountID(for word: String, in accounts: [AccountRef]) -> UUID? {
        let active = accounts.filter { !$0.archived }
        for a in active {
            let nameWords = a.name.lowercased().split(separator: " ").map(String.init)
            if nameWords.contains(word) && word.count >= 2 { return a.id }
        }
        if let kind = SlangVocabulary.accountAliases[word] {
            return active.first { $0.kind == kind }?.id
        }
        return nil
    }
}
