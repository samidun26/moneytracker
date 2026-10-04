import SwiftUI
import LocalAuthentication

/// The optional lock: when it's on, Duit asks for Face ID (or Touch ID, or
/// the iPhone passcode) when it opens and each time it comes back from the
/// background. There's no Duit-specific PIN — the iPhone's own passcode is
/// the backup, as CLAUDE.md asks (no custom auth).
enum AppLock {
    enum Outcome { case success, failed, unavailable }

    /// "Face ID", "Touch ID", or "passcode" on a phone with neither.
    static var methodName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "passcode"
        }
    }

    /// Biometrics first, the device passcode if that fails or isn't set up.
    static func authenticate(reason: String) async -> Outcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return .unavailable }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .success : .failed
        } catch {
            return .failed
        }
    }
}

/// Covers the whole app while it's locked, and (when the lock is on) while
/// the app is not active, so the app switcher never shows your money.
struct LockScreen: View {
    /// true: waiting for the user to unlock. false: just a privacy cover.
    var locked: Bool
    var onUnlock: () async -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var trying = false
    /// The prompt opens by itself once per return to the app; after a
    /// cancel, the Unlock button is the way to try again (no nagging loop).
    @State private var autoTried = false

    var body: some View {
        ZStack {
            DeskBackground()
            VStack(spacing: 16) {
                DuitLogo(points: 56)
                Text("DUIT")
                    .font(.pixel(28))
                    .foregroundStyle(Theme.ink)
                if locked {
                    Text("Locked")
                        .font(.plex(13))
                        .foregroundStyle(Theme.ink2)
                    Button { attempt() } label: {
                        Text("Unlock with \(AppLock.methodName)")
                    }
                    .buttonStyle(RetroButtonStyle(kind: .primary))
                    .disabled(trying)
                }
            }
            .padding(24)
            .background(Theme.paper)
            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
            .background { Theme.shadow.offset(x: 3, y: 3) }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: scenePhase, initial: true) {
            switch scenePhase {
            case .background:
                autoTried = false
            case .active:
                if locked && !autoTried {
                    autoTried = true
                    attempt()
                }
            default:
                break
            }
        }
    }

    private func attempt() {
        guard !trying else { return }
        trying = true
        Task { @MainActor in
            await onUnlock()
            trying = false
        }
    }
}
