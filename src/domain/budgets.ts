import type { Budget, Transaction } from '@/db/types'
import { diffDays, monthBounds, monthKey, type ISODate, type MonthKey } from '@/lib/dates'

export type BudgetStatus = 'ok' | 'warn' | 'over'

/** Expense totals per category for a month. Key `null` holds the overall total. */
export function spendingByCategory(txs: Transaction[], month: MonthKey): Map<string | null, number> {
  const m = new Map<string | null, number>()
  let total = 0
  for (const t of txs) {
    if (t.type !== 'expense' || monthKey(t.date) !== month) continue
    total += t.amount
    const key = t.categoryId
    m.set(key, (m.get(key) ?? 0) + t.amount)
  }
  m.set(null, total)
  return m
}

export function budgetStatus(ratio: number): BudgetStatus {
  if (ratio > 1) return 'over'
  if (ratio >= 0.8) return 'warn'
  return 'ok'
}

export interface BudgetProgress {
  budget: Budget
  spent: number
  limit: number
  remaining: number
  ratio: number
  status: BudgetStatus
  /** Remaining ÷ days left (incl. today). Only for the current month. */
  perDayLeft: number | null
  daysLeft: number | null
}

export function budgetProgress(budget: Budget, spent: number, month: MonthKey, today: ISODate): BudgetProgress {
  const limit = budget.amount
  const remaining = limit - spent
  const ratio = limit > 0 ? spent / limit : spent > 0 ? Infinity : 0
  let perDayLeft: number | null = null
  let daysLeft: number | null = null
  if (monthKey(today) === month) {
    daysLeft = diffDays(today, monthBounds(month).end) + 1
    perDayLeft = remaining > 0 ? Math.floor(remaining / daysLeft) : 0
  }
  return { budget, spent, limit, remaining, ratio, status: budgetStatus(ratio), perDayLeft, daysLeft }
}

/** Where spending should be by today if spread evenly (0–1). */
export function expectedPace(month: MonthKey, today: ISODate): number | null {
  if (monthKey(today) !== month) return null
  const { days } = monthBounds(month)
  return Number(today.slice(8)) / days
}

export function budgetId(categoryId: string | null): string {
  return `b-${categoryId ?? 'total'}`
}
