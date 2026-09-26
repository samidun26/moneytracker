import Foundation
import SwiftData

/// Default categories, ported from src/db/seed.ts's `DEFAULTS`. The web
/// version stamps deterministic ids so independently-seeded devices
/// converge under sync; the native MVP has no sync yet (see CLAUDE.md), so
/// plain UUIDs are fine here — revisit if/when CloudKit sync is added.
enum DefaultCategories {
    private static let items: [(kind: TransactionType, name: String, icon: String, color: CategoryColor)] = [
        (.expense, "Food & Drinks", "🍜", .orange),
        (.expense, "Coffee & Snacks", "☕", .brown),
        (.expense, "Groceries", "🛒", .green),
        (.expense, "Transport", "🛵", .blue),
        (.expense, "Housing", "🏠", .indigo),
        (.expense, "Bills & Utilities", "💡", .yellow),
        (.expense, "Subscriptions", "📺", .purple),
        (.expense, "Shopping", "🛍️", .pink),
        (.expense, "Entertainment", "🎬", .red),
        (.expense, "Health", "💊", .mint),
        (.expense, "Education", "📚", .cyan),
        (.expense, "Family", "👨‍👩‍👧", .orange),
        (.expense, "Gifts & Charity", "🎁", .teal),
        (.expense, "Travel", "✈️", .cyan),
        (.expense, "Other", "📦", .gray),
        (.income, "Salary", "💼", .green),
        (.income, "Bonus & THR", "🎉", .orange),
        (.income, "Freelance", "💻", .blue),
        (.income, "Investment", "📈", .indigo),
        (.income, "Gifts", "🎁", .pink),
        (.income, "Refunds", "↩️", .teal),
        (.income, "Other", "💰", .gray),
    ]

    /// Inserts the defaults if no categories exist yet. Call once at launch.
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = try? context.fetchCount(FetchDescriptor<Category>())
        guard existing == 0 else { return }
        for (index, item) in items.enumerated() {
            context.insert(Category(name: item.name, icon: item.icon, color: item.color, kind: item.kind, order: index))
        }
    }
}
