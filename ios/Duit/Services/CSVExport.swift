import Foundation

/// CSV export that opens in Numbers or Excel — a port of
/// `transactionsToCSV` in src/domain/backup.ts, same columns.
enum CSVExport {
    static let header = ["Date", "Type", "Amount", "Signed amount", "Category", "Account", "To account", "Note"]

    static func isoDay(_ date: Date) -> String {
        String(format: "%04ld-%02ld-%02ld", DateHelpers.year(of: date), DateHelpers.month(of: date), DateHelpers.day(of: date))
    }

    /// A cell is quoted if it holds a comma, quote or line break.
    static func cell(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    /// Newest first. Signed amount: expenses negative, income positive, transfers 0.
    static func csv(_ entries: [Entry]) -> String {
        let sorted = entries.sorted {
            $0.date != $1.date ? $0.date > $1.date : $0.createdAt > $1.createdAt
        }
        var lines = [header.map(cell).joined(separator: ",")]
        for t in sorted {
            let signed: Int
            switch t.type {
            case .expense: signed = -t.amount
            case .income: signed = t.amount
            case .transfer: signed = 0
            }
            let fields = [
                isoDay(t.date),
                t.type.rawValue,
                String(t.amount),
                String(signed),
                t.categoryName ?? "",
                t.accountName ?? "",
                t.toAccountName ?? "",
                t.title,
            ]
            lines.append(fields.map(cell).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
