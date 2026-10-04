import XCTest
import LocalAuthentication
@testable import Duit

/// The lock's rules that don't need a real Face ID prompt: which errors turn
/// the lock off (only "no passcode"), and what the user is told about the
/// passcode backup.
final class AppLockTests: XCTestCase {
    func testNoPasscodeOnThisIPhoneMakesTheLockUnavailable() {
        XCTAssertEqual(AppLock.outcome(for: LAError(.passcodeNotSet)), .unavailable)
    }

    func testEveryOtherErrorIsJustAFailedAttempt() {
        let others: [LAError.Code] = [
            .authenticationFailed, .userCancel, .userFallback, .systemCancel, .appCancel,
            .biometryNotAvailable, .biometryNotEnrolled, .biometryLockout, .notInteractive, .invalidContext,
        ]
        for code in others {
            XCTAssertEqual(AppLock.outcome(for: LAError(code)), .failed, "\(code) must keep the lock on")
        }
    }

    func testAnUnknownOrMissingErrorIsAFailedAttempt() {
        XCTAssertEqual(AppLock.outcome(for: nil), .failed)
        XCTAssertEqual(AppLock.outcome(for: NSError(domain: "other", code: LAError.Code.passcodeNotSet.rawValue)), .failed)
    }

    func testTheBackupNoteNamesTheIPhonePasscode() {
        XCTAssertTrue(AppLock.backupNote(for: "Face ID").contains("Face ID"))
        XCTAssertTrue(AppLock.backupNote(for: "Face ID").contains("iPhone passcode"))
        XCTAssertTrue(AppLock.backupNote(for: "Touch ID").contains("Touch ID"))
        XCTAssertEqual(AppLock.backupNote(for: "passcode"), "Duit uses your iPhone passcode.")
    }
}
