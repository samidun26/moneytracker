import type { SupabaseClient } from '@supabase/supabase-js'
import { getSupabaseConfig } from './config'

/**
 * Supabase is loaded lazily: the app is offline-first, so the sync SDK stays
 * out of the critical path and never delays launch from the Home Screen.
 */
let client: SupabaseClient | null = null
let clientKey = ''

export async function getClient(): Promise<SupabaseClient | null> {
  const { config } = getSupabaseConfig()
  if (!config) return null
  const key = `${config.url}|${config.key}`
  if (client && clientKey === key) return client
  const { createClient } = await import('@supabase/supabase-js')
  client = createClient(config.url, config.key, {
    auth: { persistSession: true, autoRefreshToken: true, storageKey: 'duit.auth', detectSessionInUrl: false },
  })
  clientKey = key
  return client
}

export function resetClient(): void {
  client = null
  clientKey = ''
}
