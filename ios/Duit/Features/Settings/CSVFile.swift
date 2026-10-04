import SwiftUI
import UniformTypeIdentifiers

/// The CSV written lazily at the moment the user picks where to send it
/// (ShareLink), so Settings never builds a big file just by being open.
struct CSVFile: Transferable {
    let entries: [Entry]
    let day: Date
    /// Named in the file name for every profile but the first, so the files of
    /// "Mine" and "Us" can't be mixed up.
    var profile: Profile?

    var fileName: String {
        let tag = profile.flatMap { $0.isOriginal ? nil : Self.slug($0.name) }.map { "-\($0)" } ?? ""
        return "duit\(tag)-transactions-\(CSVExport.isoDay(day)).csv"
    }

    /// "Trip fund!" → "trip-fund"
    static func slug(_ name: String) -> String {
        CSVImport.normalise(name).replacingOccurrences(of: " ", with: "-")
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(file.fileName)
            try Data(CSVExport.csv(file.entries).utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
