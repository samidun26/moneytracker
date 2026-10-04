import SwiftUI

/// A small sheet for typing one rupiah amount on the retro keypad — used for
/// spending money, salary, a wallet's opening balance, a category budget and
/// a bill. It hands the number back through `onSave`; nothing is stored here.
struct AmountEditorView: View {
    var title: String
    /// The LCD caption, e.g. "Spending money · per month".
    var caption: String
    var note: String?
    var initial: Int
    var allowZero = true
    var onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Int

    init(title: String, caption: String, note: String? = nil, initial: Int, allowZero: Bool = true, onSave: @escaping (Int) -> Void) {
        self.title = title
        self.caption = caption
        self.note = note
        self.initial = initial
        self.allowZero = allowZero
        self.onSave = onSave
        _amount = State(initialValue: initial)
    }

    private var canSave: Bool { allowZero || amount > 0 }

    var body: some View {
        RetroSheet(title: title, tint: Theme.titleColors[1], icon: PixelIconData.cash, closeLabel: "Close without saving", onClose: { dismiss() }) {
            VStack(spacing: 10) {
                LCDAmount(caption: caption, amount: amount)
                if let note {
                    Text(note)
                        .font(.plex(12.5))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Keypad { key in amount = applyKey(amount, key) }
                HStack(spacing: 12) {
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .buttonStyle(RetroButtonStyle())
                    Button("Save") {
                        onSave(amount)
                        dismiss()
                    }
                    .buttonStyle(RetroButtonStyle(kind: .primary))
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .presentationDetents([.large])
    }
}
