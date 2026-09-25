import { beforeEach, describe, expect, it, vi } from 'vitest'
import { db } from '@/db/db'
import { upsert } from '@/db/repo'
import type { RemoteRow } from './merge'

/**
 * In-memory stand-in for the Supabase `records` table + `push_records` RPC,
 * mirroring supabase/schema.sql: server-side LWW guard and a server clock cursor.
 */
class FakeServer {
  rows = new Map<string, Required<RemoteRow>>()
  clock = Date.parse('2026-09-24T00:00:00Z')
  tick() {
    this.clock += 1000
    return new Date(this.clock).toISOString()
  }
  client() {
    const server = this
    return {
      auth: { getSession: async () => ({ data: { session: { user: { id: 'u1', email: 'me@example.com' } } } }), onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }) },
      async rpc(_name: string, { items }: { items: RemoteRow[] }) {
        for (const it of items) {
          const key = `${it.tbl}/${it.id}`
          const cur = server.rows.get(key)
          if (!cur || cur.updated_at <= it.updated_at) server.rows.set(key, { ...it, server_updated_at: server.tick() })
        }
        return { error: null }
      },
      from() {
        let since = ''
        let from = 0
        let to = Infinity
        const q = {
          select: () => q,
          gt: (_c: string, v: string) => ((since = v), q),
          order: () => q,
          range: (a: number, b: number) => {
            from = a
            to = b
            const data = [...server.rows.values()]
              .filter((r) => r.server_updated_at > since)
              .sort((x, y) => x.server_updated_at.localeCompare(y.server_updated_at))
              .slice(from, to + 1)
            return Promise.resolve({ data, error: null })
          },
        }
        return q
      },
    }
  }
}

const server = new FakeServer()
vi.mock('./client', () => ({ getClient: async () => server.client(), resetClient: () => {} }))

const store = new Map<string, string>()
vi.stubGlobal('localStorage', {
  getItem: (k: string) => store.get(k) ?? null,
  setItem: (k: string, v: string) => void store.set(k, v),
  removeItem: (k: string) => void store.delete(k),
  key: (i: number) => [...store.keys()][i] ?? null,
  get length() {
    return store.size
  },
})
vi.stubGlobal('navigator', { onLine: true })

const { syncNow, getSyncState, resetCursors } = await import('./engine')

const draft = (amount: number) => ({
  type: 'expense' as const,
  amount,
  accountId: 'a1',
  toAccountId: null,
  categoryId: 'c-food',
  date: '2026-09-24',
  note: 'Bakso',
  recurringId: null,
})

async function freshDevice() {
  await Promise.all(db.tables.map((t) => t.clear()))
  resetCursors()
}

describe('sync engine (against a fake Supabase)', () => {
  beforeEach(() => {
    server.rows.clear()
    store.clear()
  })

  it('pushes local changes and a second device pulls them', async () => {
    await freshDevice()
    await upsert('transactions', { ...draft(25_000), id: 't1' })
    await syncNow()
    expect(getSyncState().status).toBe('idle')
    expect(server.rows.get('transactions/t1')?.data).toMatchObject({ amount: 25_000 })
    expect((await db.transactions.get('t1'))?.dirty).toBe(0)

    await freshDevice() // "device B"
    await syncNow()
    const pulled = await db.transactions.get('t1')
    expect(pulled).toMatchObject({ amount: 25_000, dirty: 0, deleted: 0 })
    expect(store.get('duit.sync.cursor.u1')).toBeTruthy()
  })

  it('propagates edits and deletes, and never lets an older edit win', async () => {
    await freshDevice()
    const t = await upsert('transactions', { ...draft(10_000), id: 't2' })
    await syncNow()

    // Newer edit on this device
    await upsert('transactions', { ...t, amount: 12_000 })
    await syncNow()
    expect(server.rows.get('transactions/t2')?.data).toMatchObject({ amount: 12_000 })

    // A stale device pushes an older version: server keeps the newer one
    await server.client().rpc('push_records', {
      items: [{ tbl: 'transactions', id: 't2', data: { ...t, amount: 1 }, updated_at: t.updatedAt, deleted: false }],
    })
    expect(server.rows.get('transactions/t2')?.data).toMatchObject({ amount: 12_000 })

    // Delete propagates as a tombstone
    const { remove } = await import('@/db/repo')
    await remove('transactions', ['t2'])
    await syncNow()
    expect(server.rows.get('transactions/t2')?.deleted).toBe(true)
    await freshDevice()
    await syncNow()
    expect((await db.transactions.get('t2'))?.deleted).toBe(1)
  })

  it('only pulls what changed since the cursor', async () => {
    await freshDevice()
    await upsert('transactions', { ...draft(1), id: 'a' })
    await syncNow()
    const spy = vi.spyOn(db.transactions, 'bulkPut')
    await syncNow() // nothing new except the overlap window, which merges as a no-op
    const writes = spy.mock.calls.flatMap((c) => c[0] as unknown[])
    expect(writes.length).toBeLessThanOrEqual(1)
    spy.mockRestore()
  })
})
