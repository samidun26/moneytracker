import { beforeEach, describe, expect, it } from 'vitest'
import { installMemoryStorage } from '@/test/memoryStorage'
import { deviceConfig, getSupabaseConfig, isValidSupabaseUrl, saveDeviceConfig } from './config'

beforeEach(() => {
  installMemoryStorage()
})

describe('sync settings', () => {
  it('accepts https project URLs and local development servers', () => {
    expect(isValidSupabaseUrl('https://abcd.supabase.co')).toBe(true)
    expect(isValidSupabaseUrl('  https://abcd.supabase.co/  ')).toBe(true)
    expect(isValidSupabaseUrl('http://localhost:54321')).toBe(true)
    expect(isValidSupabaseUrl('http://127.0.0.1:54321')).toBe(true)
  })

  it('rejects plain http and anything that is not a URL', () => {
    expect(isValidSupabaseUrl('http://abcd.supabase.co')).toBe(false)
    expect(isValidSupabaseUrl('abcd.supabase.co')).toBe(false)
    expect(isValidSupabaseUrl('')).toBe(false)
  })

  it('stores pasted keys cleaned up, and forgets them on disconnect', () => {
    expect(getSupabaseConfig()).toEqual({ config: null, source: null })
    saveDeviceConfig({ url: ' https://abcd.supabase.co/// ', key: '  anon-key-123  ' })
    expect(deviceConfig()).toEqual({ url: 'https://abcd.supabase.co', key: 'anon-key-123' })
    expect(getSupabaseConfig()).toEqual({ config: { url: 'https://abcd.supabase.co', key: 'anon-key-123' }, source: 'device' })
    saveDeviceConfig(null)
    expect(deviceConfig()).toBeNull()
  })

  it('ignores a half-filled config', () => {
    localStorage.setItem('duit.supabase', JSON.stringify({ url: 'https://abcd.supabase.co' }))
    expect(deviceConfig()).toBeNull()
  })
})
