import { db } from './db'
import type { AccountType, Category, CategoryKind, ColorName } from './types'

/**
 * Default categories use deterministic ids so two devices that seed
 * independently converge to the same rows after sync (no duplicates).
 * They're stamped updatedAt = 1, so any real edit always wins.
 */
const DEFAULTS: Array<[id: string, kind: CategoryKind, name: string, icon: string, color: ColorName]> = [
  ['c-food', 'expense', 'Food & Drinks', '🍜', 'orange'],
  ['c-coffee', 'expense', 'Coffee & Snacks', '☕', 'brown'],
  ['c-groceries', 'expense', 'Groceries', '🛒', 'green'],
  ['c-transport', 'expense', 'Transport', '🛵', 'blue'],
  ['c-housing', 'expense', 'Housing', '🏠', 'indigo'],
  ['c-bills', 'expense', 'Bills & Utilities', '💡', 'yellow'],
  ['c-subscriptions', 'expense', 'Subscriptions', '📺', 'purple'],
  ['c-shopping', 'expense', 'Shopping', '🛍️', 'pink'],
  ['c-entertainment', 'expense', 'Entertainment', '🎬', 'red'],
  ['c-health', 'expense', 'Health', '💊', 'mint'],
  ['c-education', 'expense', 'Education', '📚', 'cyan'],
  ['c-family', 'expense', 'Family', '👨‍👩‍👧', 'orange'],
  ['c-giving', 'expense', 'Gifts & Charity', '🎁', 'teal'],
  ['c-travel', 'expense', 'Travel', '✈️', 'cyan'],
  ['c-other-expense', 'expense', 'Other', '📦', 'gray'],
  ['c-salary', 'income', 'Salary', '💼', 'green'],
  ['c-bonus', 'income', 'Bonus & THR', '🎉', 'orange'],
  ['c-freelance', 'income', 'Freelance', '💻', 'blue'],
  ['c-investment', 'income', 'Investment', '📈', 'indigo'],
  ['c-gift-income', 'income', 'Gifts', '🎁', 'pink'],
  ['c-refund', 'income', 'Refunds', '↩️', 'teal'],
  ['c-other-income', 'income', 'Other', '💰', 'gray'],
]

export function defaultCategories(): Category[] {
  return DEFAULTS.map(([id, kind, name, icon, color], i) => ({
    id,
    kind,
    name,
    icon,
    color,
    order: i,
    createdAt: 1,
    updatedAt: 1,
    deleted: 0,
    dirty: 1,
  }))
}

export async function ensureSeeded(): Promise<void> {
  const count = await db.categories.count()
  if (count > 0) return
  await db.categories.bulkPut(defaultCategories())
}

export const ACCOUNT_TYPES: Array<{ type: AccountType; label: string; icon: string; color: ColorName }> = [
  { type: 'cash', label: 'Cash', icon: '💵', color: 'green' },
  { type: 'bank', label: 'Bank', icon: '🏦', color: 'blue' },
  { type: 'ewallet', label: 'E-wallet', icon: '📱', color: 'teal' },
  { type: 'credit', label: 'Credit card', icon: '💳', color: 'purple' },
  { type: 'savings', label: 'Savings', icon: '🐷', color: 'pink' },
]

export function accountTypeLabel(type: AccountType): string {
  return ACCOUNT_TYPES.find((t) => t.type === type)?.label ?? type
}
