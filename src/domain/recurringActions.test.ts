import { beforeEach, describe, expect, it } from 'vitest'
import { db } from '@/db/db'
import { rule } from '@/test/factories'
import { recurringTxId } from './recurring'
import { markOccurrencePaid, postDueRecurring, skipOccurrence } from './recurringActions'

beforeEach(async () => {
  await Promise.all(db.tables.map((t) => t.clear()))
})

describe('recurring actions', () => {
  it('reminder-mode rules are not logged automatically', async () => {
    await db.recurring.put(rule({ id: 'r1', autoPost: false, startDate: '2026-09-01' }))
    expect(await postDueRecurring('2026-09-24')).toBe(0)
    expect(await db.transactions.count()).toBe(0)
  })

  it('paused rules are not logged', async () => {
    await db.recurring.put(rule({ id: 'r1', active: false, startDate: '2026-09-01' }))
    expect(await postDueRecurring('2026-09-24')).toBe(0)
  })

  it('"Paid" logs the occurrence once and moves the rule forward', async () => {
    const r = rule({ id: 'r1', autoPost: false, startDate: '2026-09-01', amount: 385_000, note: 'IndiHome' })
    await db.recurring.put(r)
    await markOccurrencePaid(r, '2026-09-01')
    await markOccurrencePaid(r, '2026-09-01') // double tap: still one transaction
    const txs = await db.transactions.toArray()
    expect(txs).toHaveLength(1)
    expect(txs[0]).toMatchObject({ id: recurringTxId('r1', '2026-09-01'), amount: 385_000, note: 'IndiHome', recurringId: 'r1', date: '2026-09-01' })
    expect((await db.recurring.get('r1'))!.lastPostedDate).toBe('2026-09-01')
  })

  it('"Skip" moves the rule forward without logging anything', async () => {
    const r = rule({ id: 'r1', autoPost: false, startDate: '2026-09-01' })
    await db.recurring.put(r)
    await skipOccurrence(r, '2026-09-01')
    expect(await db.transactions.count()).toBe(0)
    expect((await db.recurring.get('r1'))!.lastPostedDate).toBe('2026-09-01')
  })

  it('never moves lastPostedDate backwards', async () => {
    const r = rule({ id: 'r1', autoPost: false, startDate: '2026-07-01', lastPostedDate: '2026-09-01' })
    await db.recurring.put(r)
    await skipOccurrence(r, '2026-08-01')
    expect((await db.recurring.get('r1'))!.lastPostedDate).toBe('2026-09-01')
  })

  it('transfer rules log a transfer with no category', async () => {
    const r = rule({ id: 'r1', type: 'transfer', toAccountId: 'a2', categoryId: 'c-subscriptions', autoPost: true, startDate: '2026-09-20', note: 'Savings' })
    await db.recurring.put(r)
    expect(await postDueRecurring('2026-09-24')).toBe(1)
    const [t] = await db.transactions.toArray()
    expect(t).toMatchObject({ type: 'transfer', accountId: 'a1', toAccountId: 'a2', categoryId: null })
  })
})
