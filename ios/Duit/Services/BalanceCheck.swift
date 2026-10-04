import Foundation

/// Balance Check: compare what Duit thinks an account holds with what the
/// user's bank or wallet app says, and guess what went unlogged. A port of
/// `balanceCandidates`, `bestCombo` and the gap logic in
/// design/prototype/Main.dc.html (minus its demo-only numbers).
enum BalanceCheck {
    struct Candidate: Equatable {
        let title: String
        let amount: Int
        let categoryName: String?
        /// How many times this exact title was logged on the account.
        let count: Int
    }

    /// Small costs that often go unlogged, per kind of account.
    static func commonExtras(for kind: AccountKind) -> [Candidate] {
        switch kind {
        case .ewallet: [Candidate(title: "Admin fee", amount: 1_000, categoryName: "Bills & Utilities", count: 0)]
        case .cash:
            [
                Candidate(title: "Parkir", amount: 2_000, categoryName: "Transport", count: 0),
                Candidate(title: "Amal Jumat", amount: 10_000, categoryName: "Other", count: 0),
            ]
        case .bank: [Candidate(title: "Admin bulanan", amount: 17_000, categoryName: "Bills & Utilities", count: 0)]
        case .credit: [Candidate(title: "Iuran kartu", amount: 25_000, categoryName: "Bills & Utilities", count: 0)]
        case .savings: []
        }
    }

    /// Up to 6 guesses: the account's most repeated purchases (at their latest
    /// price), then the usual hidden costs for that kind of account.
    /// `entries` must be **newest first**.
    static func candidates(accountID: UUID, kind: AccountKind, entries: [Entry]) -> [Candidate] {
        var seen: [String: Int] = [:] // lowercased title → index in `found`
        var found: [Candidate] = []
        for t in entries where t.type == .expense && t.accountID == accountID {
            let name = t.displayName
            let key = name.lowercased()
            if let index = seen[key] {
                let c = found[index]
                found[index] = Candidate(title: c.title, amount: c.amount, categoryName: c.categoryName, count: c.count + 1)
            } else {
                seen[key] = found.count
                found.append(Candidate(title: name, amount: t.amount, categoryName: t.categoryName, count: 1))
            }
        }
        for extra in commonExtras(for: kind) where seen[extra.title.lowercased()] == nil {
            found.append(extra)
        }
        // Most repeated first; ties keep their order.
        return found.enumerated()
            .sorted { $0.element.count != $1.element.count ? $0.element.count > $1.element.count : $0.offset < $1.offset }
            .prefix(6)
            .map { $0.element }
    }

    /// The smallest set of candidates that adds up to exactly `gap`, if any.
    static func bestCombo(_ candidates: [Candidate], gap: Int) -> [Candidate]? {
        guard gap > 0, !candidates.isEmpty, candidates.count <= 16 else { return nil }
        var best: [Candidate]?
        for mask in 1..<(1 << candidates.count) {
            var sum = 0
            var pick: [Candidate] = []
            for i in 0..<candidates.count where mask & (1 << i) != 0 {
                sum += candidates[i].amount
                pick.append(candidates[i])
            }
            if sum == gap, best == nil || pick.count < best!.count { best = pick }
        }
        return best
    }

    enum Outcome: Equatable {
        /// Nothing typed yet.
        case waiting
        case balanced
        /// Money left the account without being logged.
        case missing(Int)
        /// The account holds more than Duit expected.
        case extra(Int)
    }

    /// For a card, the user types what they *owe*; for everything else, what they *have*.
    static func outcome(isCard: Bool, duitSays: Int, appSays: Int) -> Outcome {
        guard appSays > 0 else { return .waiting }
        let gap = isCard ? appSays - duitSays : duitSays - appSays
        if gap == 0 { return .balanced }
        return gap > 0 ? .missing(gap) : .extra(-gap)
    }
}
