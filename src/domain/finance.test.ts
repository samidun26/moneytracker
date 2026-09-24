import { describe, expect, it } from 'vitest'
import { account, budget, tx } from '@/test/factories'
import { accountBalances, monthSummary, netWorth } from './balances'
import { budgetProgress, budgetStatus, spendingByCategory } from './budgets'
import { categoryBreakdown, dailyAverage, monthlyTrend } from './insights'

describe('balances', () => {
  const cash = account({ id: 'a1', openingBalance: 500_000 })
  const card = account({ id: 'a2', type: 'credit', openingBalance: -200_000 })
  const old = account({ id: 'a3', openingBalance: 1_000, archived: true })
  const txs = [
    tx({ accountId: 'a1', amount: 50_000 }),
    tx({ type: 'income', accountId: 'a1', amount: 1_000_000, categoryId: 'c-salary' }),
    tx({ type: 'transfer', accountId: 'a1', toAccountId: 'a2', amount: 200_000, categoryId: null }),
  ]
  it('computes balances with transfers', () => {
    const b = accountBalances([cash, card, old], txs)
    expect(b.get('a1')).toBe(500_000 - 50_000 + 1_000_000 - 200_000)
    expect(b.get('a2')).toBe(0)
    expect(netWorth([cash, card, old], b)).toBe(1_250_000)
  })
  it('excludes transfers from month totals', () => {
    expect(monthSummary(txs, '2026-09')).toEqual({ income: 1_000_000, expense: 50_000, net: 950_000, count: 2 })
    expect(monthSummary(txs, '2026-08').count).toBe(0)
  })
})

describe('budgets', () => {
  it('classifies status thresholds', () => {
    expect(budgetStatus(0.5)).toBe('ok')
    expect(budgetStatus(0.8)).toBe('warn')
    expect(budgetStatus(1)).toBe('warn')
    expect(budgetStatus(1.01)).toBe('over')
  })
  it('computes progress and per-day allowance for the current month', () => {
    const spent = spendingByCategory([tx({ amount: 400_000 }), tx({ amount: 200_000, categoryId: 'c-coffee' })], '2026-09')
    expect(spent.get('c-food')).toBe(400_000)
    expect(spent.get(null)).toBe(600_000)
    const p = budgetProgress(budget({ amount: 1_000_000 }), 400_000, '2026-09', '2026-09-24')
    expect(p.remaining).toBe(600_000)
    expect(p.daysLeft).toBe(7)
    expect(p.perDayLeft).toBe(85_714)
    expect(p.status).toBe('ok')
    expect(budgetProgress(budget({ amount: 1_000_000 }), 400_000, '2026-08', '2026-09-24').perDayLeft).toBeNull()
  })
})

describe('insights', () => {
  const txs = [
    tx({ amount: 300_000, categoryId: 'c-food' }),
    tx({ amount: 100_000, categoryId: 'c-coffee' }),
    tx({ amount: 200_000, categoryId: 'c-food', date: '2026-08-05' }),
    tx({ type: 'income', amount: 9_000_000, categoryId: 'c-salary', date: '2026-08-25' }),
  ]
  it('breaks spending down by category with previous month', () => {
    const b = categoryBreakdown(txs, '2026-09')
    expect(b.map((s) => [s.categoryId, s.amount, s.share, s.previous])).toEqual([
      ['c-food', 300_000, 0.75, 200_000],
      ['c-coffee', 100_000, 0.25, 0],
    ])
  })
  it('builds a 6-month trend ending at the selected month', () => {
    const t = monthlyTrend(txs, '2026-09', 6)
    expect(t).toHaveLength(6)
    expect(t[0].month).toBe('2026-04')
    expect(t[4]).toEqual({ month: '2026-08', income: 9_000_000, expense: 200_000 })
  })
  it('averages per elapsed day', () => {
    expect(dailyAverage(240_000, '2026-09', '2026-09-24')).toBe(10_000)
    expect(dailyAverage(310_000, '2026-08', '2026-09-24')).toBe(10_000)
    expect(dailyAverage(1, '2026-10', '2026-09-24')).toBe(0)
  })
})
