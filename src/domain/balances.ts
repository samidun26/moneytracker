import type { Account, Transaction } from '@/db/types'
import { monthKey, type MonthKey } from '@/lib/dates'

/** Balance per account = opening balance + income − expense ± transfers. */
export function accountBalances(accounts: Account[], txs: Transaction[]): Map<string, number> {
  const balances = new Map<string, number>()
  for (const a of accounts) balances.set(a.id, a.openingBalance)
  const add = (id: string | null, delta: number) => {
    if (id) balances.set(id, (balances.get(id) ?? 0) + delta)
  }
  for (const t of txs) {
    if (t.type === 'expense') add(t.accountId, -t.amount)
    else if (t.type === 'income') add(t.accountId, t.amount)
    else {
      add(t.accountId, -t.amount)
      add(t.toAccountId, t.amount)
    }
  }
  return balances
}

export function netWorth(accounts: Account[], balances: Map<string, number>): number {
  return accounts.filter((a) => !a.archived).reduce((sum, a) => sum + (balances.get(a.id) ?? 0), 0)
}

export interface MonthSummary {
  income: number
  expense: number
  net: number
  count: number
}

/** Transfers move money between your own accounts, so they're excluded. */
export function monthSummary(txs: Transaction[], month: MonthKey): MonthSummary {
  let income = 0
  let expense = 0
  let count = 0
  for (const t of txs) {
    if (monthKey(t.date) !== month || t.type === 'transfer') continue
    count++
    if (t.type === 'income') income += t.amount
    else expense += t.amount
  }
  return { income, expense, net: income - expense, count }
}

/** Signed effect of a transaction on one account (for account history). */
export function signedFor(t: Transaction, accountId: string): number {
  if (t.type === 'income') return t.amount
  if (t.type === 'expense') return -t.amount
  return t.accountId === accountId ? -t.amount : t.amount
}
