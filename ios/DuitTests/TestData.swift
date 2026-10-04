import Foundation
@testable import Duit

/// Small builders so the tests read like the examples they port.
enum TestData {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateHelpers.date(year: y, month: m, day: d)
    }

    static func expense(
        _ amount: Int,
        on date: Date,
        title: String = "",
        category: String? = nil,
        categoryID: UUID? = nil,
        account: UUID? = nil,
        accountName: String? = nil,
        rating: WorthRating? = nil,
        recurring: Bool = false,
        created: Date = .distantPast
    ) -> Entry {
        Entry(
            type: .expense, amount: amount, date: date, title: title,
            categoryID: categoryID, categoryName: category,
            accountID: account, accountName: accountName,
            rating: rating, isRecurring: recurring, createdAt: created
        )
    }

    static func income(
        _ amount: Int,
        on date: Date,
        title: String = "",
        category: String? = nil,
        categoryID: UUID? = nil,
        account: UUID? = nil
    ) -> Entry {
        Entry(type: .income, amount: amount, date: date, title: title, categoryID: categoryID, categoryName: category, accountID: account)
    }

    static func transfer(_ amount: Int, from: UUID, to: UUID, on date: Date) -> Entry {
        Entry(type: .transfer, amount: amount, date: date, accountID: from, toAccountID: to)
    }
}
