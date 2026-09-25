import { beforeEach, describe, expect, it } from 'vitest'
import { db } from '@/db/db'
import { account, tx } from '@/test/factories'
import { defaultCategories } from '@/db/seed'
import { createBackup, eraseLocalData, importBackup, transactionsToCSV } from './backup'

beforeEach(async () => {
  await Promise.all(db.tables.map((t) => t.clear()))
})

describe('backup', () => {
  it('exports every table without deleted rows or sync flags', async () => {
    await db.accounts.bulkPut([account({ id: 'a1', dirty: 1 }), account({ id: 'a2', deleted: 1 })])
    await db.transactions.bulkPut([tx({ id: 't1', dirty: 1 })])
    const b = await createBackup()
    expect(b.app).toBe('duit')
    expect(b.version).toBe(1)
    expect(Object.keys(b.data).sort()).toEqual(['accounts', 'budgets', 'categories', 'recurring', 'transactions'])
    expect(b.data.accounts.map((a) => a.id)).toEqual(['a1'])
    expect(b.data.transactions[0]).not.toHaveProperty('dirty')
  })

  it('merges with last-write-wins: adds new, updates older, skips newer local edits', async () => {
    await db.transactions.bulkPut([
      tx({ id: 'old', amount: 1, updatedAt: 100 }),
      tx({ id: 'newer-here', amount: 2, updatedAt: 900 }),
    ])
    const file = {
      app: 'duit',
      version: 1,
      exportedAt: '2026-09-24T00:00:00Z',
      data: {
        transactions: [
          { ...tx({ id: 'old', amount: 10 }), updatedAt: 500 },
          { ...tx({ id: 'newer-here', amount: 20 }), updatedAt: 200 },
          { ...tx({ id: 'brand-new', amount: 30 }), updatedAt: 300 },
          { id: 42, broken: true },
        ],
      },
    }
    const r = await importBackup(file)
    expect(r).toEqual({ added: 1, updated: 1, skipped: 1 })
    expect((await db.transactions.get('old'))!.amount).toBe(10)
    expect((await db.transactions.get('newer-here'))!.amount).toBe(2)
    expect((await db.transactions.get('brand-new'))!.dirty).toBe(1) // queued for sync
  })

  it('round-trips: export then import into an empty device restores everything', async () => {
    await db.categories.bulkPut(defaultCategories())
    await db.accounts.bulkPut([account({ id: 'a1' })])
    await db.transactions.bulkPut([tx({ id: 't1' }), tx({ id: 't2', type: 'income', categoryId: 'c-salary' })])
    const b = JSON.parse(JSON.stringify(await createBackup()))
    await eraseLocalData()
    expect(await db.transactions.count()).toBe(0)
    const r = await importBackup(b)
    expect(r.added).toBe(1 + 2 + defaultCategories().length)
    expect(await db.transactions.count()).toBe(2)
    expect(await importBackup(b)).toEqual({ added: 0, updated: 0, skipped: 1 + 2 + defaultCategories().length })
  })

  it('rejects files that are not Duit backups', async () => {
    await expect(importBackup({ hello: 'world' })).rejects.toThrow('This file is not a Duit backup.')
    await expect(importBackup(null)).rejects.toThrow('This file is not a Duit backup.')
    await expect(importBackup('text')).rejects.toThrow('This file is not a Duit backup.')
  })
})

describe('CSV export', () => {
  const accounts = [account({ id: 'a1', name: 'GoPay' }), account({ id: 'a2', name: 'BCA' })]
  const categories = defaultCategories()

  it('writes a header and signed amounts, newest first', () => {
    const csv = transactionsToCSV(
      [
        tx({ id: 'x', date: '2026-09-01', amount: 50_000, accountId: 'a1' }),
        tx({ id: 'y', date: '2026-09-20', type: 'income', amount: 2_000_000, accountId: 'a2', categoryId: 'c-salary' }),
        tx({ id: 'z', date: '2026-09-10', type: 'transfer', amount: 100_000, accountId: 'a2', toAccountId: 'a1', categoryId: null }),
      ],
      accounts,
      categories,
    ).split('\n')
    expect(csv[0]).toBe('Date,Type,Amount,Signed amount,Category,Account,To account,Note')
    expect(csv[1]).toBe('2026-09-20,income,2000000,2000000,Salary,BCA,,')
    expect(csv[2]).toBe('2026-09-10,transfer,100000,0,,BCA,GoPay,')
    expect(csv[3]).toBe('2026-09-01,expense,50000,-50000,Food & Drinks,GoPay,,')
  })

  it('quotes commas, quotes and new lines in notes', () => {
    const csv = transactionsToCSV([tx({ note: 'Kopi "Kenangan", 2 cups\nfor the team', accountId: 'a1' })], accounts, categories)
    expect(csv.split('\n').slice(1).join('\n')).toBe('2026-09-10,expense,10000,-10000,Food & Drinks,GoPay,,"Kopi ""Kenangan"", 2 cups\nfor the team"')
  })

  it('leaves names blank for deleted accounts or categories instead of crashing', () => {
    const csv = transactionsToCSV([tx({ accountId: 'gone', categoryId: 'gone' })], accounts, categories)
    expect(csv.split('\n')[1]).toBe('2026-09-10,expense,10000,-10000,,,,')
  })
})
