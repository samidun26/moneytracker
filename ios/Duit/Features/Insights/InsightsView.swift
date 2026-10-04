import SwiftUI

/// Placeholder until the Insights step (Month, Prices, Habits, Worth it).
struct InsightsView: View {
    let ledger: Ledger

    var body: some View {
        ScrollView {
            RetroWindow(title: "Insights", tint: Theme.titleColors[3], icon: PixelIconData.chart) {
                Text("Month, Prices and Habits are coming in the next step.")
                    .font(.plex(13))
                    .foregroundStyle(Theme.ink2)
                    .padding(14)
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
        }
    }
}
