import Dexie, { type EntityTable } from 'dexie'
import type { Account, Budget, Category, RecurringRule, Transaction } from './types'

/**
 * On-device database (IndexedDB). This is the source of truth for the UI;
 * the cloud is a replica that sync reconciles with.
 */
export class DuitDB extends Dexie {
  accounts!: EntityTable<Account, 'id'>
  categories!: EntityTable<Category, 'id'>
  transactions!: EntityTable<Transaction, 'id'>
  budgets!: EntityTable<Budget, 'id'>
  recurring!: EntityTable<RecurringRule, 'id'>

  constructor(name = 'duit') {
    super(name)
    this.version(1).stores({
      accounts: 'id, dirty',
      categories: 'id, dirty',
      transactions: 'id, dirty, date, accountId, toAccountId, categoryId, recurringId',
      budgets: 'id, dirty, categoryId',
      recurring: 'id, dirty',
    })
  }
}

export const db = new DuitDB()
