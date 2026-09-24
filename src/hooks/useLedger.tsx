import { createContext, useContext, useMemo, type ReactNode } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { db } from '@/db/db'
import type { Account, Budget, Category, RecurringRule, Transaction } from '@/db/types'
import { accountBalances } from '@/domain/balances'

export interface Ledger {
  ready: boolean
  accounts: Account[]
  activeAccounts: Account[]
  categories: Category[]
  transactions: Transaction[]
  budgets: Budget[]
  rules: RecurringRule[]
  accountById: Map<string, Account>
  categoryById: Map<string, Category>
  balances: Map<string, number>
}

const byOrder = <T extends { order: number; createdAt: number }>(a: T, b: T) => a.order - b.order || a.createdAt - b.createdAt
const newestFirst = (a: Transaction, b: Transaction) =>
  a.date < b.date ? 1 : a.date > b.date ? -1 : b.createdAt - a.createdAt

const alive = <T extends { deleted: 0 | 1 }>(rows: T[]) => rows.filter((r) => !r.deleted)

const LedgerContext = createContext<Ledger | null>(null)

/**
 * One live subscription per table for the whole app; every screen reads the
 * same derived state (balances, lookups), so numbers always agree.
 * Personal-scale data (thousands of rows) fits comfortably in memory.
 */
export function LedgerProvider({ children }: { children: ReactNode }) {
  const accounts = useLiveQuery(async () => alive(await db.accounts.toArray()).sort(byOrder), [])
  const categories = useLiveQuery(async () => alive(await db.categories.toArray()).sort(byOrder), [])
  const transactions = useLiveQuery(async () => alive(await db.transactions.toArray()).sort(newestFirst), [])
  const budgets = useLiveQuery(async () => alive(await db.budgets.toArray()), [])
  const rules = useLiveQuery(async () => alive(await db.recurring.toArray()).sort((a, b) => b.amount - a.amount), [])

  const value = useMemo<Ledger>(() => {
    const a = accounts ?? []
    const t = transactions ?? []
    return {
      ready: !!(accounts && categories && transactions && budgets && rules),
      accounts: a,
      activeAccounts: a.filter((x) => !x.archived),
      categories: categories ?? [],
      transactions: t,
      budgets: budgets ?? [],
      rules: rules ?? [],
      accountById: new Map(a.map((x) => [x.id, x])),
      categoryById: new Map((categories ?? []).map((x) => [x.id, x])),
      balances: accountBalances(a, t),
    }
  }, [accounts, categories, transactions, budgets, rules])

  return <LedgerContext.Provider value={value}>{children}</LedgerContext.Provider>
}

export function useLedger(): Ledger {
  const ctx = useContext(LedgerContext)
  if (!ctx) throw new Error('useLedger must be used inside <LedgerProvider>')
  return ctx
}
