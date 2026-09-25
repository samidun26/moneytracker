import type { ISODate } from '@/lib/dates'

/** Fields every synced record carries. */
export interface SyncFields {
  id: string
  createdAt: number
  /** Client timestamp (ms) of the last edit — used for last-write-wins. */
  updatedAt: number
  /** Soft delete so deletions sync. 0 | 1 because IndexedDB can't index booleans. */
  deleted: 0 | 1
  /** 1 = changed locally and not yet pushed to the cloud. */
  dirty: 0 | 1
}

export type AccountType = 'cash' | 'bank' | 'ewallet' | 'credit' | 'savings'
export type TxType = 'expense' | 'income' | 'transfer'
export type CategoryKind = 'expense' | 'income'
export type Frequency = 'daily' | 'weekly' | 'monthly' | 'yearly'

export interface Account extends SyncFields {
  name: string
  type: AccountType
  icon: string // emoji
  color: ColorName
  /** Integer rupiah. May be negative (e.g. credit card debt at start). */
  openingBalance: number
  archived: boolean
  order: number
}

export interface Category extends SyncFields {
  name: string
  kind: CategoryKind
  icon: string // emoji
  color: ColorName
  order: number
}

export interface Transaction extends SyncFields {
  type: TxType
  /** Positive integer rupiah; `type` decides direction. */
  amount: number
  accountId: string
  /** Transfers only */
  toAccountId: string | null
  /** Expense/income only */
  categoryId: string | null
  date: ISODate
  note: string
  /** Set when generated from a recurring rule */
  recurringId: string | null
}

export interface Budget extends SyncFields {
  /** null = overall monthly budget across all expenses */
  categoryId: string | null
  /** Monthly limit, integer rupiah */
  amount: number
}

export interface RecurringRule extends SyncFields {
  type: TxType
  amount: number
  accountId: string
  toAccountId: string | null
  categoryId: string | null
  note: string
  frequency: Frequency
  interval: number
  startDate: ISODate
  endDate: ISODate | null
  /** true: log automatically when due. false: show as "Due" to confirm. */
  autoPost: boolean
  /** Latest occurrence already handled (posted or skipped). */
  lastPostedDate: ISODate | null
  active: boolean
}

export type TableName = 'accounts' | 'categories' | 'transactions' | 'budgets' | 'recurring'
export const TABLES: TableName[] = ['accounts', 'categories', 'transactions', 'budgets', 'recurring']

export interface RecordMap {
  accounts: Account
  categories: Category
  transactions: Transaction
  budgets: Budget
  recurring: RecurringRule
}

export const COLOR_NAMES = [
  'red',
  'orange',
  'yellow',
  'green',
  'mint',
  'teal',
  'cyan',
  'blue',
  'indigo',
  'purple',
  'pink',
  'brown',
  'gray',
] as const
export type ColorName = (typeof COLOR_NAMES)[number]
