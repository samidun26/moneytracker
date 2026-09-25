import type { Table } from 'dexie'
import { uid } from '@/lib/id'
import { db } from './db'
import type { RecordMap, SyncFields, TableName } from './types'

/**
 * All local writes go through here so every change is stamped for sync
 * (updatedAt + dirty) and observers (the sync scheduler) are notified.
 */

export type Draft<T extends SyncFields> = Omit<T, keyof SyncFields> & { id?: string }

type Listener = () => void
const listeners = new Set<Listener>()

export function onLocalChange(fn: Listener): () => void {
  listeners.add(fn)
  return () => listeners.delete(fn)
}

function emit() {
  for (const fn of listeners) fn()
}

function table<K extends TableName>(name: K): Table<RecordMap[K], string> {
  return db.table(name)
}

/** Monotonic per record, so an edit never loses to its own previous version. */
function nextStamp(prev?: { updatedAt: number }): number {
  const now = Date.now()
  return prev && prev.updatedAt >= now ? prev.updatedAt + 1 : now
}

export async function upsert<K extends TableName>(name: K, draft: Draft<RecordMap[K]>): Promise<RecordMap[K]> {
  const t = table(name)
  const saved = await db.transaction('rw', t, async () => {
    const id = draft.id ?? uid()
    const prev = await t.get(id)
    const record = {
      ...prev,
      ...draft,
      id,
      createdAt: prev?.createdAt ?? Date.now(),
      updatedAt: nextStamp(prev),
      deleted: 0,
      dirty: 1,
    } as RecordMap[K]
    await t.put(record)
    return record
  })
  emit()
  return saved
}

export async function patch<K extends TableName>(
  name: K,
  id: string,
  changes: Partial<Omit<RecordMap[K], keyof SyncFields>>,
): Promise<void> {
  const t = table(name)
  await db.transaction('rw', t, async () => {
    const prev = await t.get(id)
    if (!prev) return
    await t.put({ ...prev, ...changes, updatedAt: nextStamp(prev), dirty: 1 } as RecordMap[K])
  })
  emit()
}

/** Soft delete; returns the previous records so the UI can offer Undo. */
export async function remove<K extends TableName>(name: K, ids: string[]): Promise<RecordMap[K][]> {
  const t = table(name)
  const removed = await db.transaction('rw', t, async () => {
    const prev = (await t.bulkGet(ids)).filter((r): r is RecordMap[K] => !!r && !r.deleted)
    await t.bulkPut(prev.map((r) => ({ ...r, deleted: 1, dirty: 1, updatedAt: nextStamp(r) }) as RecordMap[K]))
    return prev
  })
  emit()
  return removed
}

/** Undo a soft delete. */
export async function restore<K extends TableName>(name: K, records: RecordMap[K][]): Promise<void> {
  if (!records.length) return
  const t = table(name)
  await db.transaction('rw', t, async () => {
    const current = await t.bulkGet(records.map((r) => r.id))
    await t.bulkPut(
      records.map((r, i) => ({ ...r, deleted: 0, dirty: 1, updatedAt: nextStamp(current[i] ?? r) }) as RecordMap[K]),
    )
  })
  emit()
}

/** Notify observers after a batch write done directly on Dexie (import, recurring). */
export function notifyLocalChange(): void {
  emit()
}

export { nextStamp }
