import { readJSON, writeJSON } from '@/lib/storage'

export interface SupabaseConfig {
  url: string
  key: string
}

const KEY = 'duit.supabase'

/** Build-time config (Vercel env vars) wins; otherwise keys pasted in Settings. */
export function envConfig(): SupabaseConfig | null {
  const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
  const key = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
  return url && key ? { url, key } : null
}

export function deviceConfig(): SupabaseConfig | null {
  const c = readJSON<Partial<SupabaseConfig>>(KEY, {})
  return c.url && c.key ? { url: c.url, key: c.key } : null
}

export function getSupabaseConfig(): { config: SupabaseConfig | null; source: 'env' | 'device' | null } {
  const env = envConfig()
  if (env) return { config: env, source: 'env' }
  const device = deviceConfig()
  return { config: device, source: device ? 'device' : null }
}

export function saveDeviceConfig(config: SupabaseConfig | null): void {
  if (config) writeJSON(KEY, { url: config.url.trim().replace(/\/+$/, ''), key: config.key.trim() })
  else {
    try {
      localStorage.removeItem(KEY)
    } catch {
      /* ignore */
    }
  }
}

export function isValidSupabaseUrl(url: string): boolean {
  try {
    const u = new URL(url.trim())
    return u.protocol === 'https:' || u.hostname === 'localhost' || u.hostname === '127.0.0.1'
  } catch {
    return false
  }
}
