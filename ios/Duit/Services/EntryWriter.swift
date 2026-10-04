import Foundation
import SwiftData

/// Everything that writes transactions, in one place, so the screens stay
/// simple and the rules (which wallet, which category, undo) don't drift.
enum EntryWriter {
    /// A copy of a transaction's fields, so a delete can be undone.
    struct Snapshot {
        var type: TransactionType
        var amount: Int
        var note: String
        var date: Date
        var category: Category?
        var account: Account?
        var toAccount: Account?
        var rating: WorthRating?
        var recurringID: UUID?
        var occurrenceKey: String?

        init(_ t: Transaction) {
            type = t.type
            amount = t.amount
            note = t.note
            date = t.date
            category = t.category
            account = t.account
            toAccount = t.toAccount
            rating = t.rating
            recurringID = t.recurringID
            occurrenceKey = t.occurrenceKey
        }

        func restore(into context: ModelContext) {
            context.insert(Transaction(
                type: type, amount: amount, category: category, note: note, date: date,
                account: account, toAccount: toAccount, rating: rating,
                recurringID: recurringID, occurrenceKey: occurrenceKey
            ))
            try? context.save()
        }
    }

    /// Deletes by id (safe if it's already gone — e.g. Undo after an edit).
    static func delete(id: UUID, in context: ModelContext) {
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let tx = try? context.fetch(descriptor).first {
            context.delete(tx)
            try? context.save()
        }
    }

    /// Records the user's "worth it?" answer.
    static func rate(id: UUID, _ rating: WorthRating, in context: ModelContext) {
        var descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let tx = try? context.fetch(descriptor).first {
            tx.rating = rating
            tx.updatedAt = .now
            try? context.save()
        }
    }
}

/// Bills: post due auto-bills, and answer Paid / Skip on the others — a port
/// of src/domain/recurringActions.ts. Occurrence keys are deterministic, so
/// nothing is ever posted twice.
enum RecurringPoster {
    private static func transaction(from rule: RecurringRule, on date: Date) -> Transaction {
        Transaction(
            type: rule.type,
            amount: rule.amount,
            category: rule.type == .transfer ? nil : rule.category,
            note: rule.note,
            date: date,
            account: rule.account,
            toAccount: rule.type == .transfer ? rule.toAccount : nil,
            recurringID: rule.id,
            occurrenceKey: Recurrence.occurrenceKey(ruleID: rule.id, date: date)
        )
    }

    private static func existingKeys(_ context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        return Set(all.compactMap { $0.occurrenceKey })
    }

    /// Logs every due occurrence of auto-post rules. Returns how many were posted.
    @discardableResult
    static func postDue(in context: ModelContext, today: Date = DateHelpers.today()) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        var keys = existingKeys(context)
        var posted = 0
        for rule in rules where rule.active && rule.autoPost {
            let dates = rule.recurrence.due(lastPosted: rule.lastPostedDate, today: today, limit: 366)
            guard let latest = dates.last else { continue }
            for date in dates {
                let key = Recurrence.occurrenceKey(ruleID: rule.id, date: date)
                if keys.contains(key) { continue }
                context.insert(transaction(from: rule, on: date))
                keys.insert(key)
                posted += 1
            }
            rule.lastPostedDate = latest
        }
        if posted > 0 { try? context.save() }
        return posted
    }

    /// "Paid": log that occurrence and move the rule past it.
    static func markPaid(_ rule: RecurringRule, on date: Date, in context: ModelContext) {
        let key = Recurrence.occurrenceKey(ruleID: rule.id, date: date)
        if !existingKeys(context).contains(key) { context.insert(transaction(from: rule, on: date)) }
        rule.lastPostedDate = later(rule.lastPostedDate, date)
        try? context.save()
    }

    /// "Skip": move the rule past that occurrence without logging anything.
    static func skip(_ rule: RecurringRule, on date: Date, in context: ModelContext) {
        rule.lastPostedDate = later(rule.lastPostedDate, date)
        try? context.save()
    }

    private static func later(_ a: Date?, _ b: Date) -> Date {
        if let a, a > b { return a }
        return b
    }
}
