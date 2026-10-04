import Foundation

/// A small CSV reader for what people actually have: Duit's own export, a
/// spreadsheet's "Save as CSV" and a bank's statement download. It handles
/// quoted cells, `""` for a quote inside a cell, line breaks inside quotes,
/// CRLF / LF / CR line ends, a leading byte-order mark and any of `, ; tab |`
/// as the separator (Indonesian banks often use `;` because `,` is their
/// decimal mark).
enum CSVParser {
    static let delimiters: [Character] = [",", ";", "\t", "|"]

    /// Rows of cells; lines with nothing in them are dropped.
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        guard let separator = delimiter.unicodeScalars.first else { return [] }
        let scalars = Array(text.unicodeScalars)
        var rows: [[String]] = []
        var row: [String] = []
        var cell = String.UnicodeScalarView()
        var inQuotes = false
        var i = 0
        if scalars.first == "\u{FEFF}" { i = 1 }

        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" {
                        cell.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    cell.append(c)
                }
            } else if c == "\"" {
                // A quote opens a quoted cell only at the start of a cell
                // (spaces before it are allowed: `, "text"`); elsewhere it is text.
                if cell.allSatisfy({ $0 == " " }) {
                    cell.removeAll()
                    inQuotes = true
                } else {
                    cell.append(c)
                }
            } else if c == separator {
                row.append(String(cell))
                cell.removeAll()
            } else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < scalars.count, scalars[i + 1] == "\n" { i += 1 }
                row.append(String(cell))
                cell.removeAll()
                if !isBlank(row) { rows.append(row) }
                row = []
            } else {
                cell.append(c)
            }
            i += 1
        }
        if !cell.isEmpty || !row.isEmpty {
            row.append(String(cell))
            if !isBlank(row) { rows.append(row) }
        }
        return rows
    }

    private static func isBlank(_ row: [String]) -> Bool {
        row.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The separator that splits the first lines into the most (and most
    /// consistent) columns. Lines above the table (an account name, a period)
    /// have one column and don't vote.
    static func detectDelimiter(_ text: String) -> Character {
        let sample = String(text.prefix(20_000))
        var best: (delimiter: Character, score: Int) = (",", 0)
        for candidate in delimiters {
            let widths = parse(sample, delimiter: candidate).prefix(30).map { $0.count }
            var counts: [Int: Int] = [:]
            for w in widths where w >= 2 { counts[w, default: 0] += 1 }
            let score = counts.map { $0.key * $0.value }.max() ?? 0
            if score > best.score { best = (candidate, score) }
        }
        return best.delimiter
    }

    /// Turns the bytes of a file into text: UTF-8 (with or without a byte-order
    /// mark), UTF-16 with a mark, else Windows-1252, which is what older bank
    /// downloads and Excel on Windows write. Never fails: Latin-1 accepts any byte.
    static func text(from data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let windows = String(data: data, encoding: .windowsCP1252) { return windows }
        return String(decoding: data, as: UTF8.self)
    }
}
