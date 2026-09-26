import SwiftUI

enum KeypadKey: String {
    case zero = "0", one = "1", two = "2", three = "3", four = "4"
    case five = "5", six = "6", seven = "7", eight = "8", nine = "9"
    case triple = "000"
    case back, clear
}

private let keypadKeys: [KeypadKey] = [
    .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .triple, .zero, .back,
]

/// Pure reducer so it's testable — a direct port of `applyKey` in
/// src/components/ui/Keypad.tsx. See DuitTests/KeypadTests.swift.
func applyKey(_ amount: Int, _ key: KeypadKey, max: Int = CurrencyFormatter.maxAmount) -> Int {
    switch key {
    case .clear:
        return 0
    case .back:
        return amount / 10
    default:
        let combined = (amount == 0 ? "" : String(amount)) + key.rawValue
        guard let next = Int(combined) else { return amount }
        return next > max ? amount : next
    }
}

/// Numeric keypad with a "000" key — most rupiah amounts end in thousands.
/// Long-press-⌫-to-clear (present in the web version) is a deferred polish
/// item, not needed for the first vertical slice.
struct Keypad: View {
    var onKey: (KeypadKey) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(keypadKeys, id: \.self) { key in
                Button {
                    onKey(key)
                } label: {
                    Group {
                        if key == .back {
                            Image(systemName: "delete.left")
                        } else {
                            Text(key.rawValue)
                        }
                    }
                    .font(.system(size: 25))
                    .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.plain)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
