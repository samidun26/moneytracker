import SwiftUI
import UniformTypeIdentifiers

/// The CSV written lazily at the moment the user picks where to send it
/// (ShareLink), so Settings never builds a big file just by being open.
struct CSVFile: Transferable {
    let entries: [Entry]
    let day: Date

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("duit-transactions-\(CSVExport.isoDay(file.day)).csv")
            try Data(CSVExport.csv(file.entries).utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
