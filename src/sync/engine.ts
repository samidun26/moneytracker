import { useSyncExternalStore } from 'react'
import type { SupabaseClient } from '@supabase/supabase-js'
import { onLocalChange } from '@/db/repo'
import { readString, writeString } from '@/lib/storage'
import { getClient, resetClient } from './client'
import { collectDirty, markPushed, mergeRemote, type RemoteRow } from './merge'

/**
 * Sync engine: push local changes, then pull remote changes since a
 * server-assigned cursor. Runs on launch, after edits (debounced), when the
 * app comes to the foreground, when the network returns, and every minute.
 */

export type SyncStatus = 'disabled' | 'signed-out' | 'idle' | 'syncing' | 'offline' | 'error'

export interface SyncState {
  status: SyncStatus
  email: string | null
  userId: string | null
  lastSyncedAt: number | null
  error: string | null
}

const PAGE = 1000
const PUSH_CHUNK = 500
/** Re-read a small window before the cursor to catch rows committed out of order. */
const OVERLAP_MS = 10_000

let state: SyncState = {
  status: 'disabled',
  email: null,
  userId: null,
  lastSyncedAt: Number(readString('duit.sync.last')) || null,
  error: null,
}
const subscribers = new Set<() => void>()

function setState(patch: Partial<SyncState>) {
  state = { ...state, ...patch }
  if (patch.lastSyncedAt) writeString('duit.sync.last', String(patch.lastSyncedAt))
  for (const fn of subscribers) fn()
}

export function getSyncState(): SyncState {
  return state
}

export function useSyncState(): SyncState {
  return useSyncExternalStore(
    (fn) => {
      subscribers.add(fn)
      return () => subscribers.delete(fn)
    },
    () => state,
  )
}

const cursorKey = (userId: string) => `duit.sync.cursor.${userId}`

async function push(client: SupabaseClient): Promise<number> {
  const rows = await collectDirty()
  for (let i = 0; i < rows.length; i += PUSH_CHUNK) {
    const chunk = rows.slice(i, i + PUSH_CHUNK)
    const { error } = await client.rpc('push_records', { items: chunk })
    if (error) throw new Error(error.message)
    await markPushed(chunk)
  }
  return rows.length
}

async function pull(client: SupabaseClient, userId: string): Promise<number> {
  const cursor = readString(cursorKey(userId))
  const since = cursor ? new Date(Date.parse(cursor) - OVERLAP_MS).toISOString() : '1970-01-01T00:00:00Z'
  let maxSeen = cursor
  let applied = 0
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await client
      .from('records')
      .select('tbl,id,data,updated_at,deleted,server_updated_at')
      .gt('server_updated_at', since)
      .order('server_updated_at', { ascending: true })
      .order('id', { ascending: true })
      .range(from, from + PAGE - 1)
    if (error) throw new Error(error.message)
    const rows = (data ?? []) as RemoteRow[]
    applied += await mergeRemote(rows)
    for (const r of rows) {
      if (r.server_updated_at && (!maxSeen || Date.parse(r.server_updated_at) > Date.parse(maxSeen))) {
        maxSeen = r.server_updated_at
      }
    }
    if (rows.length < PAGE) break
  }
  if (maxSeen) writeString(cursorKey(userId), maxSeen)
  return applied
}

let running: Promise<void> | null = null
let rerun = false

async function runOnce(): Promise<void> {
  const client = await getClient()
  if (!client) return setState({ status: 'disabled', email: null, userId: null })
  const { data } = await client.auth.getSession()
  const user = data.session?.user
  if (!user) return setState({ status: 'signed-out', email: null, userId: null })
  setState({ email: user.email ?? null, userId: user.id })
  if (!navigator.onLine) return setState({ status: 'offline' })
  setState({ status: 'syncing', error: null })
  try {
    await push(client)
    await pull(client, user.id)
    setState({ status: 'idle', lastSyncedAt: Date.now(), error: null })
  } catch (e) {
    setState({ status: navigator.onLine ? 'error' : 'offline', error: humanizeError(e) })
  }
}

/** Run a sync now; concurrent calls coalesce into one follow-up run. */
export function syncNow(): Promise<void> {
  if (running) {
    rerun = true
    return running
  }
  running = (async () => {
    do {
      rerun = false
      await runOnce()
    } while (rerun)
  })().finally(() => {
    running = null
  })
  return running
}

let started = false
let debounce: ReturnType<typeof setTimeout> | undefined
let authUnsub: (() => void) | null = null

export function scheduleSync(delay = 1500): void {
  clearTimeout(debounce)
  debounce = setTimeout(() => void syncNow(), delay)
}

/** Wire up triggers once at app start. Resolves after the first sync attempt. */
export async function startSync(): Promise<void> {
  if (!started) {
    started = true
    onLocalChange(() => scheduleSync())
    window.addEventListener('online', () => void syncNow())
    window.addEventListener('offline', () => setState({ status: state.userId ? 'offline' : state.status }))
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') scheduleSync(300)
    })
    setInterval(() => {
      if (document.visibilityState === 'visible') void syncNow()
    }, 60_000)
  }
  await watchAuth()
  await syncNow()
}

async function watchAuth() {
  authUnsub?.()
  authUnsub = null
  const client = await getClient()
  if (!client) return
  const { data } = client.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED' || event === 'SIGNED_OUT') {
      setState({ email: session?.user.email ?? null, userId: session?.user.id ?? null })
      if (event !== 'TOKEN_REFRESHED') scheduleSync(0)
    }
  })
  authUnsub = () => data.subscription.unsubscribe()
}

/** Call after the Supabase URL/key changes in Settings. */
export async function reconfigureSync(): Promise<void> {
  resetClient()
  await watchAuth()
  await syncNow()
}

export async function signIn(email: string, password: string): Promise<void> {
  const client = await getClient()
  if (!client) throw new Error('Connect a Supabase project first.')
  const { error } = await client.auth.signInWithPassword({ email: email.trim(), password })
  if (error) throw new Error(humanizeError(error))
  await syncNow()
}

/** Returns true if the account needs email confirmation before signing in. */
export async function signUp(email: string, password: string): Promise<boolean> {
  const client = await getClient()
  if (!client) throw new Error('Connect a Supabase project first.')
  const { data, error } = await client.auth.signUp({ email: email.trim(), password })
  if (error) throw new Error(humanizeError(error))
  if (!data.session) return true
  await syncNow()
  return false
}

export async function signOut(): Promise<void> {
  const client = await getClient()
  await client?.auth.signOut()
  setState({ status: 'signed-out', email: null, userId: null, lastSyncedAt: null })
  writeString('duit.sync.last', null)
}

/** Forget all sync cursors so the next sync re-downloads everything. */
export function resetCursors(): void {
  try {
    Object.keys(localStorage)
      .filter((k) => k.startsWith('duit.sync.cursor.'))
      .forEach((k) => localStorage.removeItem(k))
  } catch {
    /* ignore */
  }
}

function humanizeError(e: unknown): string {
  const msg = e instanceof Error ? e.message : typeof e === 'object' && e && 'message' in e ? String(e.message) : String(e)
  if (/Failed to fetch|NetworkError|Load failed/i.test(msg)) return 'Can’t reach the server. Check your connection.'
  if (/Invalid login credentials/i.test(msg)) return 'Wrong email or password.'
  if (/Email not confirmed/i.test(msg)) return 'Confirm your email first — check your inbox.'
  if (/push_records|relation .*records|does not exist|schema cache/i.test(msg))
    return 'Database not set up. Run supabase/schema.sql in your Supabase SQL editor.'
  if (/Invalid API key|No API key/i.test(msg)) return 'The Supabase key looks wrong.'
  return msg
}
