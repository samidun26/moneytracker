import SwiftUI

extension CategoryColor {
    /// Maps to Apple's own dynamic system colors. These already adapt to
    /// light/dark exactly like the web app's `--sys-*` CSS variables
    /// (src/styles/index.css) — which are themselves Apple's HIG palette
    /// hand-copied into CSS — so using the real UIKit colors here is more
    /// faithful than re-hardcoding hex values, and stays correct if Apple
    /// ever nudges the palette.
    var color: Color {
        switch self {
        case .red: Color(uiColor: .systemRed)
        case .orange: Color(uiColor: .systemOrange)
        case .yellow: Color(uiColor: .systemYellow)
        case .green: Color(uiColor: .systemGreen)
        case .mint: Color(uiColor: .systemMint)
        case .teal: Color(uiColor: .systemTeal)
        case .cyan: Color(uiColor: .systemCyan)
        case .blue: Color(uiColor: .systemBlue)
        case .indigo: Color(uiColor: .systemIndigo)
        case .purple: Color(uiColor: .systemPurple)
        case .pink: Color(uiColor: .systemPink)
        case .brown: Color(uiColor: .systemBrown)
        case .gray: Color(uiColor: .systemGray)
        }
    }
}

/// Emoji-on-a-soft-colored-circle badge — ports
/// src/components/ui/IconBadge.tsx + src/lib/colors.ts's `colorSoft`
/// (18% tint background behind the emoji, e.g. 🍜 on soft orange).
struct IconBadge: View {
    var icon: String
    var color: CategoryColor
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(color.color.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(Text(icon).font(.system(size: size * 0.5)))
    }
}
