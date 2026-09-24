import { db } from '@/db/db'
import { TABLES, type RecordMap, type TableName } from '@/db/types'

/** Row shape in the Supabase `records` table. */
export interface RemoteRow {
  tbl: string
  id: string
  data: object
  updated_at: number
  deleted: boolean
  server_updated_at?: string
}

export function toRemote(tbl: TableName, rec: RecordMap[TableName]): RemoteRow {
  const { dirty: _dirty, ...data } = rec
  return { tbl, id: rec.id, data, updated_at: rec.updatedAt, deleted: rec.deleted === 1 }
}

/**
 * Last-write-wins merge of pulled rows into IndexedDB.
 * A local unsynced edit that's newer (or equal) is kept — it'll be pushed next.
 * Idempotent: merging the same rows twice is a no-op.
 */
export async function mergeRemote(rows: RemoteRow[]): Promise<number> {
  let applied = 0
  const byTable = new Map<TableName, RemoteRow[]>()
  for (const r of rows) {
    if (!(TABLES as string[]).includes(r.tbl)) continue // unknown table from a newer app version
    const list = byTable.get(r.tbl as TableName) ?? []
    list.push(r)
    byTable.set(r.tbl as TableName, list)
  }
  for (const [name, list] of byTable) {
    const t = db.table(name)
    await db.transaction('rw', t, async () => {
      const locals = (await t.bulkGet(list.map((r) => r.id))) as Array<RecordMap[TableName] | undefined>
      const puts: unknown[] = []
      list.forEach((r, i) => {
        const local = locals[i]
        const remoteWins =
          !local || r.updated_at > local.updatedAt || (r.updated_at === local.updatedAt && local.dirty === 0)
        if (!remoteWins) return
        puts.push({ ...r.data, id: r.id, updatedAt: r.updated_at, deleted: r.deleted ? 1 : 0, dirty: 0 })
      })
      if (puts.length) await t.bulkPut(puts)
      applied += puts.length
    })
  }
  return applied
}

export async function collectDirty(): Promise<RemoteRow[]> {
  const out: RemoteRow[] = []
  for (const name of TABLES) {
    const rows = (await db.table(name).where('dirty').equals(1).toArray()) as Array<RecordMap[TableName]>
    for (const r of rows) out.push(toRemote(name, r))
  }
  return out
}

/** After a successful push, clear the dirty flag — unless the record changed meanwhile. */
export async function markPushed(rows: RemoteRow[]): Promise<void> {
  const byTable = new Map<string, RemoteRow[]>()
  for (const r of rows) byTable.set(r.tbl, [...(byTable.get(r.tbl) ?? []), r])
  for (const [name, list] of byTable) {
    const t = db.table(name)
    await db.transaction('rw', t, async () => {
      const locals = (await t.bulkGet(list.map((r) => r.id))) as Array<RecordMap[TableName] | undefined>
      const puts = locals
        .map((l, i) => (l && l.updatedAt === list[i].updated_at ? { ...l, dirty: 0 } : null))
        .filter(Boolean)
      if (puts.length) await t.bulkPut(puts)
    })
  }
}

export async function countDirty(): Promise<number> {
  let n = 0
  for (const name of TABLES) n += await db.table(name).where('dirty').equals(1).count()
  return n
}
