import type { Transaction } from '@/db/types'
import { monthBounds, monthKey, shiftMonth, type ISODate, type MonthKey } from '@/lib/dates'

export interface CategorySlice {
  categoryId: string | null
  amount: number
  share: number
  count: number
  /** Same category, previous month */
  previous: number
}

export function categoryBreakdown(
  txs: Transaction[],
  month: MonthKey,
  kind: 'expense' | 'income' = 'expense',
): CategorySlice[] {
  const prevMonth = shiftMonth(month, -1)
  const cur = new Map<string | null, { amount: number; count: number }>()
  const prev = new Map<string | null, number>()
  let total = 0
  for (const t of txs) {
    if (t.type !== kind) continue
    const m = monthKey(t.date)
    if (m === month) {
      const e = cur.get(t.categoryId) ?? { amount: 0, count: 0 }
      e.amount += t.amount
      e.count++
      cur.set(t.categoryId, e)
      total += t.amount
    } else if (m === prevMonth) {
      prev.set(t.categoryId, (prev.get(t.categoryId) ?? 0) + t.amount)
    }
  }
  return [...cur.entries()]
    .map(([categoryId, e]) => ({
      categoryId,
      amount: e.amount,
      count: e.count,
      share: total ? e.amount / total : 0,
      previous: prev.get(categoryId) ?? 0,
    }))
    .sort((a, b) => b.amount - a.amount)
}

export interface TrendPoint {
  month: MonthKey
  income: number
  expense: number
}

export function monthlyTrend(txs: Transaction[], endMonth: MonthKey, months = 6): TrendPoint[] {
  const points = new Map<MonthKey, TrendPoint>()
  for (let i = months - 1; i >= 0; i--) {
    const m = shiftMonth(endMonth, -i)
    points.set(m, { month: m, income: 0, expense: 0 })
  }
  for (const t of txs) {
    const p = points.get(monthKey(t.date))
    if (!p || t.type === 'transfer') continue
    if (t.type === 'income') p.income += t.amount
    else p.expense += t.amount
  }
  return [...points.values()]
}

/** Average spend per elapsed day (whole month if it's in the past). */
export function dailyAverage(expense: number, month: MonthKey, today: ISODate): number {
  const { days } = monthBounds(month)
  const elapsed = monthKey(today) === month ? Number(today.slice(8)) : monthKey(today) < month ? 0 : days
  return elapsed > 0 ? Math.round(expense / elapsed) : 0
}

export function largestExpense(txs: Transaction[], month: MonthKey): Transaction | null {
  let best: Transaction | null = null
  for (const t of txs) {
    if (t.type === 'expense' && monthKey(t.date) === month && (!best || t.amount > best.amount)) best = t
  }
  return best
}

/** Cumulative spend per day of month — for the pace chart. */
export function cumulativeDaily(txs: Transaction[], month: MonthKey): number[] {
  const { days } = monthBounds(month)
  const perDay = new Array<number>(days).fill(0)
  for (const t of txs) {
    if (t.type === 'expense' && monthKey(t.date) === month) perDay[Number(t.date.slice(8)) - 1] += t.amount
  }
  let run = 0
  return perDay.map((v) => (run += v))
}

/** Expense total for the first `day` days of a month — for fair month-to-date comparisons. */
export function monthToDateExpense(txs: Transaction[], month: MonthKey, day: number): number {
  let sum = 0
  for (const t of txs) {
    if (t.type === 'expense' && monthKey(t.date) === month && Number(t.date.slice(8)) <= day) sum += t.amount
  }
  return sum
}
