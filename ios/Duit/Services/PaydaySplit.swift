import Foundation

/// Payday Split: give every rupiah a job; what's left is spending money and
/// refills the battery (design/prototype/Main.dc.html `splitRows`, `spend`).
enum PaydaySplit {
    /// Each + / − tap moves a bucket by this much.
    static let step = 250_000

    static func spendingMoney(salary: Int, buckets: [Int]) -> Int {
        salary - buckets.reduce(0, +)
    }

    /// A daily allowance for the spending money, until the next payday.
    static func perDay(spending: Int, daysUntilNextPayday: Int) -> Int {
        guard spending > 0 else { return 0 }
        return Int(floor(Double(spending) / Double(max(1, daysUntilNextPayday))))
    }

    static func stepped(_ amount: Int, by delta: Int) -> Int {
        max(0, amount + delta)
    }
}
