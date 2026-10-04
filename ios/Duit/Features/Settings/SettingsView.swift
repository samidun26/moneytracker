import SwiftUI

/// Placeholder until the Settings step (look, payday, wallets, budgets, lock, data).
struct SettingsView: View {
    let ledger: Ledger

    var body: some View {
        ScrollView {
            RetroWindow(title: "Settings", tint: Theme.titleColors[4], icon: PixelIconData.panel) {
                Text("Look, payday, wallets and data settings are coming in the next step.")
                    .font(.plex(13))
                    .foregroundStyle(Theme.ink2)
                    .padding(14)
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
        }
    }
}
