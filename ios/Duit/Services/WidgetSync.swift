import Foundation
import WidgetKit

/// Hands the latest snapshot to the widgets and asks WidgetKit to redraw
/// them — but only when something actually changed, so editing a note
/// doesn't spend the widgets' refresh budget.
enum WidgetSync {
    static func push(_ snapshot: WidgetSnapshot) {
        guard snapshot != WidgetSnapshot.load() else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
