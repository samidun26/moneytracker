import { beforeEach, describe, expect, it, vi } from 'vitest'
import { db } from './db'
import { nextStamp, onLocalChange, patch, remove, restore, upsert } from './repo'

beforeEach(async () => {
  await Promise.all(db.tables.map((t) => t.clear()))
})

const draft = { type: 'expense' as const, amount: 25_000, accountId: 'a1', toAccountId: null, categoryId: 'c-food', date: '2026-09-24', note: 'Mie Ayam', recurringId: null }

describe('local writes', () => {
  it('stamps new records for sync and notifies listeners', async () => {
    const listener = vi.fn()
    const off = onLocalChange(listener)
    const t = await upsert('transactions', draft)
    off()
    expect(t.id).toMatch(/.+/)
    expect(t.createdAt).toBeGreaterThan(0)
    expect(t.updatedAt).toBeGreaterThan(0)
    expect(t.dirty).toBe(1)
    expect(t.deleted).toBe(0)
    expect(listener).toHaveBeenCalledTimes(1)
  })

  it('keeps createdAt on edit and always moves updatedAt forward', async () => {
    const first = await upsert('transactions', draft)
    const second = await upsert('transactions', { ...draft, id: first.id, amount: 30_000 })
    expect(second.createdAt).toBe(first.createdAt)
    expect(second.updatedAt).toBeGreaterThan(first.updatedAt)
    expect(nextStamp({ updatedAt: Date.now() + 60_000 })).toBeGreaterThan(Date.now() + 60_000)
  })

  it('patch changes only the given fields', async () => {
    const t = await upsert('transactions', draft)
    await patch('transactions', t.id, { note: 'Bakso' })
    const after = await db.transactions.get(t.id)
    expect(after!.note).toBe('Bakso')
    expect(after!.amount).toBe(25_000)
    await patch('transactions', 'missing', { note: 'x' }) // no-op, no throw
  })

  it('delete is soft and Undo brings the record back', async () => {
    const t = await upsert('transactions', draft)
    const removed = await remove('transactions', [t.id])
    expect(removed.map((r) => r.id)).toEqual([t.id])
    const gone = await db.transactions.get(t.id)
    expect(gone!.deleted).toBe(1)
    expect(gone!.dirty).toBe(1) // the delete syncs too
    await restore('transactions', removed)
    const back = await db.transactions.get(t.id)
    expect(back!.deleted).toBe(0)
    expect(back!.updatedAt).toBeGreaterThan(gone!.updatedAt) // Undo wins over the delete everywhere
  })

  it('deleting something already deleted returns nothing to undo', async () => {
    const t = await upsert('transactions', draft)
    await remove('transactions', [t.id])
    expect(await remove('transactions', [t.id])).toEqual([])
  })
})
