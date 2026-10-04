import Foundation

/// One transaction read from a file, before it is matched to a wallet and a category.
struct ImportRow: Equatable {
    /// Which row of the file it came from (blank lines don't count; the header is row 1).
    var row: Int
    var date: Date
    var type: TransactionType
    /// Whole rupiah, always above zero.
    var amount: Int
    var title: String
    var categoryName: String?
    /// The wallet named in the file (Duit exports); nil for bank statements.
    var accountName: String?
    var toAccountName: String?
    var rating: WorthRating?
    /// Kept from a Duit export so the same file can be imported twice safely.
    var id: UUID?
}

/// A row that was left out because it couldn't be read.
struct ImportProblem: Equatable {
    var row: Int
    var reason: String
}

struct ImportFile {
    enum Kind { case duit, statement }

    var kind: Kind
    var rows: [ImportRow]
    var problems: [ImportProblem]
    /// A bank statement whose single amount column carries no sign, DB/CR marker
    /// or type column, so "money in or out" was assumed (positive = money in).
    /// The preview lets the user flip it.
    var directionIsGuessed: Bool
}

enum ImportFailure: Error, Equatable {
    case empty
    case noColumns
    case noTransactions

    var message: String {
        switch self {
        case .empty:
            "That file is empty."
        case .noColumns:
            "Duit couldn't find the columns it needs. A bank statement needs a Date column and either an Amount column or Debit and Credit columns, with the column names in one of its first rows."
        case .noTransactions:
            "The columns look right, but there are no transactions under them."
        }
    }
}

/// Reads a CSV into `ImportRow`s. Two kinds of file are understood:
///
/// - **Duit's own export** (Settings → Export CSV), read back exactly:
///   `Date, Type, Amount, Signed amount, Category, Account, To account, Note`,
///   plus `ID` and `Worth it` in newer exports. Older exports without them work too.
/// - **A bank or e-wallet statement.** The column names are found by themselves,
///   in English or Indonesian: a date; a description; and the money as either
///   Debit + Credit columns, or one Amount column whose sign, DB/CR marker or a
///   Type column says which way it went.
enum CSVImport {
    /// Bigger than any real statement; stops a wrong file from freezing the app.
    static let maxBytes = 5_000_000

    static func read(_ text: String) -> Result<ImportFile, ImportFailure> {
        let table = CSVParser.parse(text, delimiter: CSVParser.detectDelimiter(text))
        guard !table.isEmpty else { return .failure(.empty) }
        if let duit = readDuit(table) { return duit }
        return readStatement(table)
    }

    // MARK: Cells and headers

    /// Lowercase letters and digits separated by single spaces, accents removed:
    /// "Tanggal  Transaksi" → "tanggal transaksi".
    static func normalise(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var out = ""
        var lastWasSpace = true
        for ch in folded {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastWasSpace = false
            } else if !lastWasSpace {
                out.append(" ")
                lastWasSpace = true
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Collapses runs of whitespace; bank descriptions are padded with spaces.
    static func tidy(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func cell(_ line: [String], _ index: Int?) -> String {
        guard let index, index < line.count else { return "" }
        var text = line[index].trimmingCharacters(in: .whitespacesAndNewlines)
        // Excel's "text" marker in front of a date or number.
        if text.hasPrefix("'") { text.removeFirst() }
        return text
    }

    private static func isEmpty(_ line: [String]) -> Bool {
        line.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: Duit's own export

    private static func readDuit(_ table: [[String]]) -> Result<ImportFile, ImportFailure>? {
        let header = table[0].map { normalise($0) }
        guard let dateCol = header.firstIndex(of: "date"),
              let typeCol = header.firstIndex(of: "type"),
              let amountCol = header.firstIndex(of: "amount"),
              header.contains("signed amount") || header.contains("to account") else { return nil }
        let categoryCol = header.firstIndex(of: "category")
        let accountCol = header.firstIndex(of: "account")
        let toCol = header.firstIndex(of: "to account")
        let noteCol = header.firstIndex(of: "note")
        let idCol = header.firstIndex(of: "id")
        let worthCol = header.firstIndex(of: "worth it")

        var rows: [ImportRow] = []
        var problems: [ImportProblem] = []
        for (index, line) in table.enumerated().dropFirst() where !isEmpty(line) {
            let number = index + 1
            guard let date = ImportDate.parse(cell(line, dateCol)) else {
                problems.append(ImportProblem(row: number, reason: "date not recognised: \(cell(line, dateCol))"))
                continue
            }
            guard let type = transactionType(cell(line, typeCol)) else {
                problems.append(ImportProblem(row: number, reason: "unknown type: \(cell(line, typeCol))"))
                continue
            }
            guard let amount = ImportAmount.parse(cell(line, amountCol))?.value, amount > 0 else {
                problems.append(ImportProblem(row: number, reason: "no amount"))
                continue
            }
            let from = cell(line, accountCol)
            let to = cell(line, toCol)
            if type == .transfer && (from.isEmpty || to.isEmpty) {
                problems.append(ImportProblem(row: number, reason: "a transfer needs both wallets"))
                continue
            }
            let category = cell(line, categoryCol)
            rows.append(ImportRow(
                row: number,
                date: date,
                type: type,
                amount: amount,
                title: tidy(cell(line, noteCol)),
                categoryName: type == .transfer || category.isEmpty ? nil : category,
                accountName: from.isEmpty ? nil : from,
                toAccountName: type == .transfer ? to : nil,
                rating: worthRating(cell(line, worthCol)),
                id: UUID(uuidString: cell(line, idCol))
            ))
        }
        if rows.isEmpty && problems.isEmpty { return .failure(.noTransactions) }
        return .success(ImportFile(kind: .duit, rows: rows, problems: problems, directionIsGuessed: false))
    }

    private static func transactionType(_ text: String) -> TransactionType? {
        let wanted = text.trimmingCharacters(in: .whitespaces).lowercased()
        return [TransactionType.expense, .income, .transfer].first { $0.rawValue.lowercased() == wanted }
    }

    private static func worthRating(_ text: String) -> WorthRating? {
        switch normalise(text) {
        case "worth", "worth it": .worth
        case "regret", "nyesel": .regret
        default: nil
        }
    }

    // MARK: Bank statements

    private enum Column: Hashable {
        case date, description, weakDescription, debit, credit, amount, indicator, balance
    }

    private static let indicatorHeaders: Set<String> = [
        "type", "tipe", "jenis", "transaction type", "tipe transaksi", "jenis transaksi", "mutation type",
        "jenis mutasi", "cr db", "db cr", "cr dr", "dr cr", "d c", "dc", "d k", "dk", "debit credit", "debit kredit",
    ]
    private static let balanceWords = ["balance", "saldo"]
    private static let debitWords = ["debit", "debet", "db", "dr", "withdrawal", "withdrawals", "keluar", "pengeluaran", "paid out", "money out"]
    private static let creditWords = ["credit", "kredit", "cr", "kr", "deposit", "deposits", "masuk", "pemasukan", "paid in", "money in"]
    private static let dateWords = ["date", "tanggal", "tgl", "waktu", "time", "datetime", "timestamp"]
    private static let amountWords = ["amount", "jumlah", "nominal", "mutasi", "nilai"]
    private static let descriptionWords = [
        "description", "deskripsi", "keterangan", "remark", "remarks", "details", "detail", "uraian",
        "berita", "narration", "narrative", "note", "notes", "catatan", "merchant", "payee",
    ]
    private static let weakDescriptionWords = ["reference", "memo", "title", "transaction", "transaksi", "information", "informasi"]

    private static func has(_ header: String, anyOf words: [String]) -> Bool {
        let padded = " \(header) "
        return words.contains { padded.contains(" \($0) ") }
    }

    private static func column(for header: String) -> Column? {
        guard !header.isEmpty else { return nil }
        if indicatorHeaders.contains(header) { return .indicator }
        if has(header, anyOf: balanceWords) { return .balance }
        if has(header, anyOf: debitWords) { return .debit }
        if has(header, anyOf: creditWords) { return .credit }
        if has(header, anyOf: dateWords) { return .date }
        if has(header, anyOf: amountWords) { return .amount }
        if has(header, anyOf: descriptionWords) { return .description }
        if has(header, anyOf: weakDescriptionWords) { return .weakDescription }
        return nil
    }

    private struct Layout {
        var headerRow: Int
        var date: Int
        var description: Int?
        var debit: Int?
        var credit: Int?
        var amount: Int?
        var indicator: Int?
    }

    /// The first row (within the first 40) that looks like column names: a date
    /// column and something that holds money.
    private static func findLayout(_ table: [[String]]) -> Layout? {
        for (index, line) in table.prefix(40).enumerated() {
            var found: [Column: Int] = [:]
            for (i, text) in line.enumerated() {
                guard let role = column(for: normalise(text)), found[role] == nil else { continue }
                found[role] = i
            }
            guard let date = found[.date],
                  found[.amount] != nil || found[.debit] != nil || found[.credit] != nil else { continue }
            return Layout(
                headerRow: index,
                date: date,
                description: found[.description] ?? found[.weakDescription],
                debit: found[.debit],
                credit: found[.credit],
                amount: found[.amount],
                indicator: found[.indicator]
            )
        }
        return nil
    }

    private enum Money {
        /// Nothing in the money cells: a balance line, a total, a blank.
        case none
        case unreadable(String)
        case found(amount: Int, type: TransactionType, explicit: Bool)
    }

    private static func money(in line: [String], _ layout: Layout) -> Money {
        // Separate Debit and Credit columns: whichever one is filled says it.
        if layout.debit != nil && layout.credit != nil {
            let debitText = cell(line, layout.debit)
            let creditText = cell(line, layout.credit)
            let debit = ImportAmount.parse(debitText)
            let credit = ImportAmount.parse(creditText)
            if (!debitText.isEmpty && debit == nil) || (!creditText.isEmpty && credit == nil) {
                return .unreadable("amount not recognised")
            }
            switch ((debit?.value ?? 0) > 0, (credit?.value ?? 0) > 0) {
            case (true, false): return .found(amount: debit?.value ?? 0, type: .expense, explicit: true)
            case (false, true): return .found(amount: credit?.value ?? 0, type: .income, explicit: true)
            case (true, true): return .unreadable("both Debit and Credit are filled in")
            case (false, false): return .none
            }
        }

        // One money column (an Amount column, or a lone Debit / Credit column).
        guard let source = layout.amount ?? layout.debit ?? layout.credit else { return .none }
        let text = cell(line, source)
        guard !text.isEmpty else { return .none }
        guard let parsed = ImportAmount.parse(text) else { return .unreadable("amount not recognised") }
        guard parsed.value > 0 else { return .none }

        var direction = parsed.direction
        if layout.amount == nil {
            direction = layout.debit != nil ? ImportAmount.Direction.moneyOut : ImportAmount.Direction.moneyIn
        }
        if direction == nil { direction = indicatorDirection(cell(line, layout.indicator)) }
        // No sign, no marker, no type column: assume positive means money in.
        return .found(amount: parsed.value, type: direction == .moneyOut ? .expense : .income, explicit: direction != nil)
    }

    private static func indicatorDirection(_ text: String) -> ImportAmount.Direction? {
        let word = normalise(text)
        if ["db", "dr", "d", "dbt", "debit", "debet", "keluar", "out", "tarik"].contains(word) { return .moneyOut }
        if ["cr", "k", "c", "kr", "credit", "kredit", "masuk", "in", "setor"].contains(word) { return .moneyIn }
        return nil
    }

    private static func readStatement(_ table: [[String]]) -> Result<ImportFile, ImportFailure> {
        guard let layout = findLayout(table) else { return .failure(.noColumns) }
        let body = Array(table.enumerated().dropFirst(layout.headerRow + 1)).filter { !isEmpty($0.element) }
        let order = ImportDate.detectOrder(body.map { cell($0.element, layout.date) })

        var rows: [ImportRow] = []
        var problems: [ImportProblem] = []
        var sawDirection = false
        for (index, line) in body {
            let number = index + 1
            switch money(in: line, layout) {
            case .none:
                continue
            case .unreadable(let reason):
                problems.append(ImportProblem(row: number, reason: reason))
            case .found(let amount, let type, let explicit):
                let dateText = cell(line, layout.date)
                guard let date = ImportDate.parse(dateText, order: order) else {
                    problems.append(ImportProblem(row: number, reason: dateText.isEmpty ? "no date" : "date not recognised: \(dateText)"))
                    continue
                }
                if explicit { sawDirection = true }
                rows.append(ImportRow(
                    row: number,
                    date: date,
                    type: type,
                    amount: amount,
                    title: String(tidy(cell(line, layout.description)).prefix(120)),
                    categoryName: nil,
                    accountName: nil,
                    toAccountName: nil,
                    rating: nil,
                    id: nil
                ))
            }
        }
        if rows.isEmpty && problems.isEmpty { return .failure(.noTransactions) }
        return .success(ImportFile(kind: .statement, rows: rows, problems: problems, directionIsGuessed: !sawDirection && !rows.isEmpty))
    }
}
