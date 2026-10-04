import Foundation
import SwiftData

/// What kind of wallet an account is (src/db/types.ts `AccountType`,
/// src/db/seed.ts `ACCOUNT_TYPES`). The kind picks the icon and color, and
/// the Add screen uses it to pick a sensible default wallet.
enum AccountKind: String, Codable, CaseIterable {
    case cash, bank, ewallet, credit, savings

    var label: String {
        switch self {
        case .cash: "Cash"
        case .bank: "Bank"
        case .ewallet: "E-wallet"
        case .credit: "Credit card"
        case .savings: "Savings"
        }
    }

    var color: CategoryColor {
        switch self {
        case .cash: .green
        case .bank: .blue
        case .ewallet: .teal
        case .credit: .purple
        case .savings: .pink
        }
    }

    /// The prototype's wallet icons: cash, bank, phone (GoPay), card (Visa).
    var icon: PixelRects {
        switch self {
        case .cash: PixelIconData.cash
        case .bank, .savings: PixelIconData.bank
        case .ewallet: PixelIconData.phone
        case .credit: PixelIconData.card
        }
    }
}

/// A wallet: cash, a bank account, an e-wallet, a credit card, savings.
/// Mirrors src/db/types.ts `Account`. Balance is never stored — it's always
/// computed as opening balance + income − expense ± transfers
/// (src/domain/balances.ts), so it can't drift.
@Model
final class Account {
    var id: UUID
    var name: String
    var kind: AccountKind
    var color: CategoryColor
    /// Integer rupiah. May be negative (e.g. credit card debt at the start).
    var openingBalance: Int
    var archived: Bool
    var order: Int
    /// When the user last ran Balance Check on this account.
    var lastCheckedAt: Date?

    /// The other side of `Transaction.account` / `Transaction.toAccount`.
    /// Declaring them lets SwiftData clear those references if the account is
    /// deleted, instead of leaving transactions pointing at nothing.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction] = []
    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        color: CategoryColor? = nil,
        openingBalance: Int = 0,
        archived: Bool = false,
        order: Int = 0,
        lastCheckedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.color = color ?? kind.color
        self.openingBalance = openingBalance
        self.archived = archived
        self.order = order
        self.lastCheckedAt = lastCheckedAt
    }
}
