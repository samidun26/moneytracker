import WidgetKit
import SwiftUI

/// Duit's widgets: what you've spent (with the Tanggal Tua battery), and a
/// one-tap shortcut that opens the app on a new expense.
@main
struct DuitWidgetBundle: WidgetBundle {
    init() {
        // The retro fonts ship inside this extension too; the app's
        // registration doesn't carry over to this process.
        DuitFonts.registerAll()
    }

    var body: some Widget {
        SpendingWidget()
        QuickAddWidget()
    }
}
