import SwiftUI

/// The "PAYDAY!" boot screen: a dark start-up screen with a progress bar that
/// fills in ten steps, then hands over to the Payday Split (prototype
/// `.boot`). With Reduce Motion on, it shows everything at once.
struct PaydayBootView: View {
    var salary: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var steps = 0
    @State private var lines = 0

    private let ink = Color(hex: 0xE6E3F4)
    private let dim = Color(hex: 0xAAA6CC)

    var body: some View {
        ZStack {
            Color(hex: 0x141633).ignoresSafeArea()
            VStack(spacing: 14) {
                DuitLogo(points: 90, outline: ink)
                Text("DUIT OS")
                    .font(.pixel(32))
                    .foregroundStyle(ink)
                Text("PAYDAY!")
                    .font(.pixel(16))
                    .foregroundStyle(Color(hex: 0xFFD45C))

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: 0x4ADE80))
                        .frame(width: 212 * CGFloat(steps) / 10)
                    Spacer(minLength: 0)
                }
                .padding(2)
                .frame(width: 220, height: 22)
                .overlay(Rectangle().strokeBorder(ink, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    line("Salary day ... \(CurrencyFormatter.formatRp(salary))", visible: lines >= 1)
                    line("Refilling battery ... OK", visible: lines >= 2)
                    line("Opening Payday Split ...", visible: lines >= 3)
                }
                .padding(.top, 6)
            }
            .padding(24)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Payday. Refilling your battery.")
        .task { await run() }
    }

    private func line(_ text: String, visible: Bool) -> some View {
        Text(text)
            .font(.plex(13))
            .foregroundStyle(dim)
            .opacity(visible ? 1 : 0)
    }

    private func run() async {
        if reduceMotion {
            steps = 10
            lines = 3
            return
        }
        for step in 1...10 {
            try? await Task.sleep(for: .milliseconds(150))
            steps = step
            if step == 3 { lines = 1 }
            if step == 6 { lines = 2 }
            if step == 9 { lines = 3 }
        }
    }
}
