import Foundation

/// UserDefaults keys for simple settings, shared by the views (@AppStorage)
/// and by code that has no view (the theme's dynamic colors, the lock).
///
/// Some settings belong to the whole device (look, lock) and live in
/// `UserDefaults.standard`. Others belong to one **profile** (payday day,
/// salary, the split done for a period, the wallet used last): they live in
/// `Prefs.profile`, which is the active profile's own defaults. The original
/// profile uses `.standard` itself, so nothing that was saved before profiles
/// existed has to move.
enum Prefs {
    /// Where the active profile's own settings live (see `ProfilePrefs`). Set
    /// when the app starts and whenever the profile is switched, before the
    /// screens are rebuilt; read it, don't cache it.
    static var profile: UserDefaults = .standard

    /// "auto" | "day" | "night"
    static let theme = "pref.theme"
    /// "candy" | "arcade" | "sunset"
    static let palette = "pref.palette"
    static let texture = "pref.texture"
    static let faceLock = "pref.faceLock"
    /// Day of the month the salary arrives (1...31).
    static let paydayDay = "pref.paydayDay"
    /// Monthly salary, integer rupiah (0 = not set).
    static let salary = "pref.salary"
    /// Start date (timeIntervalSince1970) of the pay period the split was last done for.
    static let lastSplitPeriod = "pref.lastSplitPeriod"
    /// The account used for the last expense, offered first next time.
    static let lastExpenseAccount = "pref.lastExpenseAccount"
    static let lastIncomeAccount = "pref.lastIncomeAccount"

    static let defaultPaydayDay = 1

    static var paletteName: String {
        UserDefaults.standard.string(forKey: palette) ?? "candy"
    }

    static var paydayDayValue: Int {
        let v = profile.integer(forKey: paydayDay)
        return v == 0 ? defaultPaydayDay : min(31, max(1, v))
    }
}
