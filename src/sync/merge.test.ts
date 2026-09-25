import { beforeEach, describe, expect, it } from 'vitest'
import { db } from '@/db/db'
import { upsert } from '@/db/repo'
import { tx } from '@/test/factories'
import { collectDirty, markPushed, mergeRemote } from './merge'
import { postDueRecurring } from '@/domain/recurringActions'
import { rule } from '@/test/factories'

beforeEach(async () => {
  await Promise.all(db.tables.map((t) => t.clear()))
})

describe('sync merge (last-write-wins)', () => {
  it('applies newer remote rows and keeps newer local edits', async () => {
    await db.transactions.bulkPut([
      tx({ id: 't1', amount: 1, updatedAt: 100, dirty: 0 }),
      tx({ id: 't2', amount: 2, updatedAt: 300, dirty: 1 }),
    ])
    const remote = (id: string, amount: number, updated_at: number) => ({
      tbl: 'transactions',
      id,
      data: { ...tx({ id, amount }), updatedAt: updated_at },
      updated_at,
      deleted: false,
    })
    const applied = await mergeRemote([remote('t1', 10, 200), remote('t2', 20, 250), remote('t3', 30, 50)])
    expect(applied).toBe(2)
    expect((await db.transactions.get('t1'))?.amount).toBe(10)
    expect((await db.transactions.get('t2'))?.amount).toBe(2) // local newer, kept
    expect((await db.transactions.get('t3'))?.dirty).toBe(0)
  })

  it('syncs soft deletes and ignores unknown tables', async () => {
    await db.transactions.put(tx({ id: 't1', updatedAt: 1, dirty: 0 }))
    await mergeRemote([
      { tbl: 'transactions', id: 't1', data: tx({ id: 't1' }), updated_at: 5, deleted: true },
      { tbl: 'from_the_future', id: 'x', data: {}, updated_at: 5, deleted: false },
    ])
    expect((await db.transactions.get('t1'))?.deleted).toBe(1)
  })

  it('is idempotent', async () => {
    const row = { tbl: 'transactions', id: 't1', data: tx({ id: 't1', amount: 7 }), updated_at: 9, deleted: false }
    await mergeRemote([row])
    await mergeRemote([row])
    expect(await db.transactions.count()).toBe(1)
  })

  it('clears dirty only if the record did not change during push', async () => {
    const saved = await upsert('transactions', { ...tx(), id: 't1' })
    const dirty = await collectDirty()
    expect(dirty.map((d) => d.id)).toEqual(['t1'])
    expect(dirty[0].data).not.toHaveProperty('dirty')
    await upsert('transactions', { ...saved, amount: 999 }) // edited mid-push
    await markPushed(dirty)
    expect((await db.transactions.get('t1'))?.dirty).toBe(1)
    await markPushed(await collectDirty())
    expect((await db.transactions.get('t1'))?.dirty).toBe(0)
  })
})

describe('recurring auto-post', () => {
  it('posts each due occurrence once, with deterministic ids', async () => {
    await db.recurring.put(rule({ id: 'net', startDate: '2026-07-10' }))
    expect(await postDueRecurring('2026-09-24')).toBe(3)
    expect(await postDueRecurring('2026-09-24')).toBe(0)
    const ids = (await db.transactions.toArray()).map((t) => t.id).sort()
    expect(ids).toEqual(['r-net-2026-07-10', 'r-net-2026-08-10', 'r-net-2026-09-10'])
    expect((await db.recurring.get('net'))?.lastPostedDate).toBe('2026-09-10')
  })

  it('does not resurrect an occurrence the user deleted', async () => {
    await db.recurring.put(rule({ id: 'net', startDate: '2026-09-10' }))
    await db.transactions.put(tx({ id: 'r-net-2026-09-10', deleted: 1 }))
    expect(await postDueRecurring('2026-09-24')).toBe(0)
  })
})
