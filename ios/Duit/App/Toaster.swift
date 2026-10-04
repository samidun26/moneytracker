import SwiftUI
import Observation

/// The little dark note with Undo ("Saved Kopi · Rp 32.000"). One at a time;
/// a new one replaces the old, and it fades after 4.5 seconds.
@MainActor
@Observable
final class Toaster {
    struct Message: Identifiable {
        let id = UUID()
        let text: String
        let undo: (() -> Void)?
    }

    var current: Message?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ text: String, undo: (() -> Void)? = nil) {
        let message = Message(text: text, undo: undo)
        current = message
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled, let self, self.current?.id == message.id else { return }
            self.current = nil
        }
    }

    func performUndo() {
        let undo = current?.undo
        hideTask?.cancel()
        current = nil
        undo?()
    }
}
