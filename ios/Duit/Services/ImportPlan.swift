import Foundation

/// What importing a file would do, worked out without touching the database:
/// which rows are new, which are already in Duit, which wallets would have to
/// be created, and which category each new row gets.
struct ImportPlan {
    struct Item: Equatable {
        var row: ImportRow
        /// The wallet it goes to, spelled as the existing wallet (or the file, for a new one).
        var accountName: String
        var toAccountName: String?
        var categoryName: String?
    }

    var items: [Item]
    /// Rows that match something already logged.
    var duplicates: Int
    /// Wallets named in the file that don't exist yet.
    var newWallets: [String]
    var problems: [ImportProblem]

    var incomeTotal: Int { items.filter { $0.row.type == .income }.reduce(0) { $0 + $1.row.amount } }
    var expenseTotal: Int { items.filter { $0.row.type == .expense }.reduce(0) { $0 + $1.row.amount } }

    /// - Parameters:
    ///   - defaultWallet: the wallet for rows that name none (all bank-statement rows).
    ///   - positiveIsIncome: only used when the file's direction was guessed; `false` flips every row.
    static func make(
        file: ImportFile,
        existing: [Entry],
        wallets: [AccountRef],
        defaultWallet: String?,
        positiveIsIncome: Bool = true
    ) -> ImportPlan {
        let flip = file.kind == .statement && file.directionIsGuessed && !positiveIsIncome
        // A statement's wording never matches what you typed ("QRIS KOPI KENANGAN"
        // vs "Kopi"), so for statements the day, amount and wallet are what count.
        let looseMatch = file.kind == .statement

        var knownWallets: [String: String] = [:]
        for wallet in wallets where knownWallets[CSVImport.normalise(wallet.name)] == nil {
            knownWallets[CSVImport.normalise(wallet.name)] = wallet.name
        }
        var newWallets: [String] = []
        func resolve(_ name: String) -> String {
            let key = CSVImport.normalise(name)
            if let known = knownWallets[key] { return known }
            knownWallets[key] = name
            newWallets.append(name)
            return name
        }

        var seenIDs = Set(existing.map { $0.id })
        var counts: [String: Int] = [:]
        for entry in existing {
            counts[matchKey(entry.type, entry.date, entry.amount, entry.accountName ?? "", entry.toAccountName ?? "", entry.title, loose: looseMatch), default: 0] += 1
        }
        let history = looseMatch ? CategoryHistory(existing) : nil

        var items: [Item] = []
        var duplicates = 0
        var problems = file.problems
        for source in file.rows {
            var row = source
            if flip { row.type = row.type == .income ? .expense : .income }

            let named = row.accountName.flatMap { $0.isEmpty ? nil : $0 } ?? defaultWallet
            guard let walletName = named else {
                problems.append(ImportProblem(row: row.row, reason: "no wallet to put it in"))
                continue
            }
            let account = resolve(walletName)
            let toAccount = row.toAccountName.map { resolve($0) }

            if let id = row.id {
                if seenIDs.contains(id) {
                    duplicates += 1
                    continue
                }
                seenIDs.insert(id)
            }
            let key = matchKey(row.type, row.date, row.amount, account, toAccount ?? "", row.title, loose: looseMatch)
            if let left = counts[key], left > 0 {
                counts[key] = left - 1
                duplicates += 1
                continue
            }

            items.append(Item(
                row: row,
                accountName: account,
                toAccountName: toAccount,
                categoryName: row.categoryName ?? history?.guess(for: row.title, type: row.type)
            ))
        }
        return ImportPlan(items: items, duplicates: duplicates, newWallets: newWallets, problems: problems)
    }

    /// Two rows with the same key are "the same transaction". A key is counted,
    /// not just checked: two real Rp 20.000 lunches on one day stay two.
    private static func matchKey(
        _ type: TransactionType, _ date: Date, _ amount: Int,
        _ account: String, _ toAccount: String, _ title: String, loose: Bool
    ) -> String {
        [
            type.rawValue,
            CSVExport.isoDay(date),
            String(amount),
            CSVImport.normalise(account),
            CSVImport.normalise(toAccount),
            loose ? "" : CSVImport.normalise(title),
        ].joined(separator: "|")
    }
}

/// Guesses a category for a bank-statement row from what the user already
/// logged: the same title, or a statement description that contains one of
/// their titles ("QRIS KOPI KENANGAN SCBD" contains "Kopi Kenangan").
struct CategoryHistory {
    private struct Known {
        let type: TransactionType
        let title: String
        let category: String
    }

    private let known: [Known]

    init(_ entries: [Entry]) {
        // Newest first, so the most recent choice wins a tie.
        let newestFirst = entries.sorted { $0.date > $1.date }
        known = newestFirst.compactMap { entry -> Known? in
            guard entry.type != .transfer, let category = entry.categoryName else { return nil }
            let title = CSVImport.normalise(entry.title)
            return title.isEmpty ? nil : Known(type: entry.type, title: title, category: category)
        }
    }

    func guess(for description: String, type: TransactionType) -> String? {
        let text = CSVImport.normalise(description)
        guard !text.isEmpty else { return nil }
        var best: Known?
        for entry in known where entry.type == type {
            if entry.title == text { return entry.category }
            // Short titles ("ayam") would match inside unrelated words.
            guard entry.title.count >= 4, " \(text) ".contains(" \(entry.title) ") else { continue }
            if let current = best, current.title.count >= entry.title.count { continue }
            best = entry
        }
        return best?.category
    }
}

/// Picks a wallet type for a wallet that exists only in an imported file.
enum WalletGuess {
    static func kind(for name: String) -> AccountKind {
        // Whole words only: "dana" is an e-wallet, "Danamon" is a bank.
        let padded = " \(CSVImport.normalise(name)) "
        func mentions(_ words: [String]) -> Bool { words.contains { padded.contains(" \($0) ") } }
        if mentions(["gopay", "ovo", "dana", "shopeepay", "linkaja", "link aja", "isaku", "wallet", "flip"]) { return .ewallet }
        if mentions(["cash", "tunai", "dompet"]) { return .cash }
        if mentions(["credit", "kredit", "visa", "mastercard"]) { return .credit }
        if mentions(["saving", "savings", "tabungan", "deposito", "emas"]) { return .savings }
        return .bank
    }
}
