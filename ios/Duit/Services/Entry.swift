import Foundation

/// A plain-value snapshot of one transaction. Every calculation in
/// Services/ works on these instead of SwiftData objects, so the rules can be
/// unit-tested without a database and can't accidentally write to one.
struct Entry: Identifiable, Hashable {
    let id: UUID
    var type: TransactionType
    var amount: Int
    var date: Date
    /// The note/title the user typed ("Mie Ayam"). May be empty.
    var title: String
    var categoryID: UUID?
    var categoryName: String?
    var categoryIcon: String?
    var categoryColor: CategoryColor?
    var accountID: UUID?
    var accountName: String?
    var toAccountID: UUID?
    var toAccountName: String?
    var rating: WorthRating?
    var isRecurring: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: TransactionType = .expense,
        amount: Int,
        date: Date,
        title: String = "",
        categoryID: UUID? = nil,
        categoryName: String? = nil,
        categoryIcon: String? = nil,
        categoryColor: CategoryColor? = nil,
        accountID: UUID? = nil,
        accountName: String? = nil,
        toAccountID: UUID? = nil,
        toAccountName: String? = nil,
        rating: WorthRating? = nil,
        isRecurring: Bool = false,
        createdAt: Date = .distantPast
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.date = date
        self.title = title
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.categoryColor = categoryColor
        self.accountID = accountID
        self.accountName = accountName
        self.toAccountID = toAccountID
        self.toAccountName = toAccountName
        self.rating = rating
        self.isRecurring = isRecurring
        self.createdAt = createdAt
    }

    init(_ t: Transaction) {
        self.init(
            id: t.id,
            type: t.type,
            amount: t.amount,
            date: t.date,
            title: t.note.trimmingCharacters(in: .whitespaces),
            categoryID: t.category?.id,
            categoryName: t.category?.name,
            categoryIcon: t.category?.icon,
            categoryColor: t.category?.color,
            accountID: t.account?.id,
            accountName: t.account?.name,
            toAccountID: t.toAccount?.id,
            toAccountName: t.toAccount?.name,
            rating: t.rating,
            isRecurring: t.recurringID != nil,
            createdAt: t.createdAt
        )
    }

    /// What a list row calls it: the title, else the category (or "Transfer").
    var displayName: String {
        if !title.isEmpty { return title }
        if type == .transfer { return "Transfer" }
        return categoryName ?? "Uncategorized"
    }
}

/// A plain-value snapshot of an account.
struct AccountRef: Identifiable, Hashable {
    let id: UUID
    var name: String
    var kind: AccountKind
    var openingBalance: Int
    var archived: Bool

    init(id: UUID = UUID(), name: String, kind: AccountKind, openingBalance: Int = 0, archived: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.openingBalance = openingBalance
        self.archived = archived
    }

    init(_ a: Account) {
        self.init(id: a.id, name: a.name, kind: a.kind, openingBalance: a.openingBalance, archived: a.archived)
    }
}
