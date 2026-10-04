import Foundation

/// Which wallet to suggest when the user hasn't picked one: the one they used
/// last time, else the usual choice for the kind of entry (an e-wallet for
/// spending, a bank for income) — the prototype defaults to GoPay and BCA.
enum AccountDefaults {
    static func expense(_ accounts: [AccountRef], last: UUID?) -> UUID? {
        let active = accounts.filter { !$0.archived }
        if let last, active.contains(where: { $0.id == last }) { return last }
        return (active.first { $0.kind == .ewallet } ?? active.first { $0.kind == .cash } ?? active.first)?.id
    }

    static func income(_ accounts: [AccountRef], last: UUID?) -> UUID? {
        let active = accounts.filter { !$0.archived }
        if let last, active.contains(where: { $0.id == last }) { return last }
        return (active.first { $0.kind == .bank } ?? active.first)?.id
    }

    /// The two wallets a new transfer starts with: from a bank (or cash) into an e-wallet.
    static func transferPair(_ accounts: [AccountRef]) -> (from: UUID?, to: UUID?) {
        let active = accounts.filter { !$0.archived }
        let to = active.first { $0.kind == .ewallet } ?? active.first
        let from = active.first { $0.kind == .bank && $0.id != to?.id }
            ?? active.first { $0.kind == .cash && $0.id != to?.id }
            ?? active.first { $0.id != to?.id }
        return (from?.id, to?.id)
    }

    static func read(_ key: String) -> UUID? {
        UserDefaults.standard.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    static func remember(_ id: UUID?, key: String) {
        UserDefaults.standard.set(id?.uuidString, forKey: key)
    }
}
