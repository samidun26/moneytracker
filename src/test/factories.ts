import type { Account, Budget, RecurringRule, Transaction } from '@/db/types'

let n = 0
const meta = () => ({ id: `id-${++n}`, createdAt: n, updatedAt: n, deleted: 0 as const, dirty: 0 as const })

export function account(p: Partial<Account> = {}): Account {
  return { ...meta(), name: 'Cash', type: 'cash', icon: '💵', color: 'green', openingBalance: 0, archived: false, order: 0, ...p }
}

export function tx(p: Partial<Transaction> = {}): Transaction {
  return {
    ...meta(),
    type: 'expense',
    amount: 10_000,
    accountId: 'a1',
    toAccountId: null,
    categoryId: 'c-food',
    date: '2026-09-10',
    note: '',
    recurringId: null,
    ...p,
  }
}

export function budget(p: Partial<Budget> = {}): Budget {
  return { ...meta(), categoryId: 'c-food', amount: 1_000_000, ...p }
}

export function rule(p: Partial<RecurringRule> = {}): RecurringRule {
  return {
    ...meta(),
    type: 'expense',
    amount: 186_000,
    accountId: 'a1',
    toAccountId: null,
    categoryId: 'c-subscriptions',
    note: 'Netflix',
    frequency: 'monthly',
    interval: 1,
    startDate: '2026-01-31',
    endDate: null,
    autoPost: true,
    lastPostedDate: null,
    active: true,
    ...p,
  }
}
