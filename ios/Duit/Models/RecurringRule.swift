import Foundation
import SwiftData

enum Frequency: String, Codable, CaseIterable {
    case daily, weekly, monthly, yearly

    var label: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

/// A bill or subscription that repeats (src/db/types.ts `RecurringRule`).
/// With `autoPost` it logs itself when due; without, it shows up in To do as
/// "Due" until the user taps Paid or Skip. The schedule math lives in
/// Services/Recurrence.swift.
@Model
final class RecurringRule {
    var id: UUID
    var type: TransactionType
    var amount: Int
    @Relationship(deleteRule: .nullify)
    var account: Account?
    @Relationship(deleteRule: .nullify)
    var toAccount: Account?
    @Relationship(deleteRule: .nullify)
    var category: Category?
    var note: String
    var frequency: Frequency
    var interval: Int
    var startDate: Date
    var endDate: Date?
    /// true: log automatically when due. false: show as "Due" to confirm.
    var autoPost: Bool
    /// Latest occurrence already handled (posted or skipped).
    var lastPostedDate: Date?
    var active: Bool

    init(
        id: UUID = UUID(),
        type: TransactionType = .expense,
        amount: Int,
        account: Account? = nil,
        toAccount: Account? = nil,
        category: Category? = nil,
        note: String,
        frequency: Frequency = .monthly,
        interval: Int = 1,
        startDate: Date,
        endDate: Date? = nil,
        autoPost: Bool = false,
        lastPostedDate: Date? = nil,
        active: Bool = true
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.account = account
        self.toAccount = toAccount
        self.category = category
        self.note = note
        self.frequency = frequency
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.autoPost = autoPost
        self.lastPostedDate = lastPostedDate
        self.active = active
    }

    var recurrence: Recurrence {
        Recurrence(frequency: frequency, interval: interval, startDate: startDate, endDate: endDate)
    }
}
