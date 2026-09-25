import { db } from '@/db/db'
import { notifyLocalChange } from '@/db/repo'
import { TABLES, type Account, type Category, type RecordMap, type TableName, type Transaction } from '@/db/types'

export interface BackupFile {
  app: 'duit'
  version: 1
  exportedAt: string
  data: { [K in TableName]: Array<Omit<RecordMap[K], 'dirty'>> }
}

export async function createBackup(): Promise<BackupFile> {
  const data = {} as BackupFile['data']
  for (const name of TABLES) {
    const rows = (await db.table(name).toArray()) as Array<RecordMap[typeof name]>
    ;(data as Record<string, unknown[]>)[name] = rows.filter((r) => !r.deleted).map(({ dirty: _d, ...rest }) => rest)
  }
  return { app: 'duit', version: 1, exportedAt: new Date().toISOString(), data }
}

export interface ImportResult {
  added: number
  updated: number
  skipped: number
}

/** Merge a backup using last-write-wins, so importing never clobbers newer edits. */
export async function importBackup(file: unknown): Promise<ImportResult> {
  if (!isBackup(file)) throw new Error('This file is not a Duit backup.')
  const result: ImportResult = { added: 0, updated: 0, skipped: 0 }
  await db.transaction('rw', TABLES.map((t) => db.table(t)), async () => {
    for (const name of TABLES) {
      const rows = (file.data[name] ?? []) as Array<RecordMap[typeof name]>
      const valid = rows.filter((r) => r && typeof r.id === 'string' && typeof r.updatedAt === 'number')
      const existing = await db.table(name).bulkGet(valid.map((r) => r.id))
      const puts: unknown[] = []
      valid.forEach((r, i) => {
        const cur = existing[i] as RecordMap[typeof name] | undefined
        if (!cur) result.added++
        else if (r.updatedAt > cur.updatedAt) result.updated++
        else return void result.skipped++
        puts.push({ ...r, deleted: r.deleted ? 1 : 0, dirty: 1 })
      })
      await db.table(name).bulkPut(puts)
    }
  })
  notifyLocalChange()
  return result
}

function isBackup(f: unknown): f is BackupFile {
  return !!f && typeof f === 'object' && (f as BackupFile).app === 'duit' && typeof (f as BackupFile).data === 'object'
}

function csvCell(v: string | number): string {
  const s = String(v)
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

export function transactionsToCSV(txs: Transaction[], accounts: Account[], categories: Category[]): string {
  const acc = new Map(accounts.map((a) => [a.id, a.name]))
  const cat = new Map(categories.map((c) => [c.id, c.name]))
  const header = ['Date', 'Type', 'Amount', 'Signed amount', 'Category', 'Account', 'To account', 'Note']
  const rows = [...txs]
    .sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : b.createdAt - a.createdAt))
    .map((t) => [
      t.date,
      t.type,
      t.amount,
      t.type === 'expense' ? -t.amount : t.type === 'income' ? t.amount : 0,
      t.categoryId ? (cat.get(t.categoryId) ?? '') : '',
      acc.get(t.accountId) ?? '',
      t.toAccountId ? (acc.get(t.toAccountId) ?? '') : '',
      t.note,
    ])
  return [header, ...rows].map((r) => r.map(csvCell).join(',')).join('\n')
}

/** Save a file: iOS share sheet ("Save to Files") when available, else a download. */
export async function saveFile(name: string, content: string, type: string): Promise<void> {
  const file = new File([content], name, { type })
  const nav = navigator as Navigator & { canShare?: (d: ShareData) => boolean }
  if (nav.canShare?.({ files: [file] }) && /iPhone|iPad|iPod/.test(navigator.userAgent)) {
    try {
      await navigator.share({ files: [file], title: name })
      return
    } catch (e) {
      if ((e as DOMException).name === 'AbortError') return
    }
  }
  const url = URL.createObjectURL(file)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  document.body.appendChild(a)
  a.click()
  a.remove()
  setTimeout(() => URL.revokeObjectURL(url), 10_000)
}

export async function eraseLocalData(): Promise<void> {
  await db.transaction('rw', TABLES.map((t) => db.table(t)), async () => {
    for (const t of TABLES) await db.table(t).clear()
  })
  notifyLocalChange()
}
