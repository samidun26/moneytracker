import SwiftUI
import LocalAuthentication

/// The optional lock: when it's on, Duit asks for Face ID (or Touch ID) when
/// it opens and each time it comes back from the background, and for the
/// iPhone's own passcode if that doesn't work. There's no Duit-specific PIN:
/// the passcode is the backup, as CLAUDE.md asks (no custom auth).
enum AppLock {
    enum Outcome: Equatable { case success, failed, unavailable }

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

    /// What happens when the face (or finger) isn't recognised; shown under
    /// the lock's switch in Settings and on the lock screen.
    static func backupNote(for method: String) -> String {
        method == "passcode"
            ? "Duit uses your iPhone passcode."
            : "If \(method) doesn't work, your iPhone passcode unlocks Duit instead."
    }

    /// Face ID (or Touch ID) first, then the iPhone passcode. The policy
    /// `.deviceOwnerAuthentication` is what makes the passcode the backup:
    /// when the face isn't recognised, Face ID is locked out after too many
    /// tries, or it isn't set up, iOS asks for the passcode in the same prompt.
    /// (`.deviceOwnerAuthenticationWithBiometrics` would not; it fails instead.)
    static func authenticate(reason: String) async -> Outcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return outcome(for: error)
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .success : .failed
        } catch {
            return outcome(for: error)
        }
    }

    /// Only "this iPhone has no passcode" makes the lock unavailable. Anything
    /// else (cancelling, a wrong passcode, the app being interrupted, a
    /// momentary system error) is just a failed attempt: the lock stays on
    /// and you can try again, so a hiccup never switches your lock off.
    static func outcome(for error: Error?) -> Outcome {
        (error as? LAError)?.code == .passcodeNotSet ? .unavailable : .failed
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
                    let method = AppLock.methodName
                    Text("Locked")
                        .font(.plex(13))
                        .foregroundStyle(Theme.ink2)
                    Button { attempt() } label: {
                        Text("Unlock with \(method)")
                    }
                    .buttonStyle(RetroButtonStyle(kind: .primary))
                    .disabled(trying)
                    Text(AppLock.backupNote(for: method))
                        .font(.plex(12))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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
