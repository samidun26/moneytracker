import { beforeEach, describe, expect, it, vi } from 'vitest'
import { installMemoryStorage } from '@/test/memoryStorage'
import { getLockout, getLockSettings, saveLockSettings, setPin, verifyPin } from './lock'

beforeEach(() => {
  installMemoryStorage()
  vi.useRealTimers()
})

describe('app lock PIN', () => {
  it('starts off, with a 60-second auto-lock', () => {
    expect(getLockSettings()).toEqual({ enabled: false, pinHash: null, pinSalt: null, biometricId: null, autoLockSeconds: 60 })
  })

  it('stores only a salted hash, never the PIN itself', async () => {
    await setPin('246810')
    const s = getLockSettings()
    expect(s.pinHash).toBeTruthy()
    expect(s.pinSalt).toBeTruthy()
    expect(JSON.stringify(localStorage.getItem('duit.lock'))).not.toContain('246810')
    const firstHash = s.pinHash
    await setPin('246810')
    expect(getLockSettings().pinHash).not.toBe(firstHash) // new salt every time
  })

  it('accepts the right PIN and rejects a wrong one', async () => {
    await setPin('246810')
    expect(await verifyPin('246810')).toEqual({ ok: true, waitMs: 0 })
    expect((await verifyPin('000000')).ok).toBe(false)
  })

  it('no PIN set means nothing unlocks', async () => {
    expect(await verifyPin('123456')).toEqual({ ok: false, waitMs: 0 })
  })

  it('locks out for 30s after 5 wrong tries, then doubles', async () => {
    await setPin('246810')
    for (let i = 0; i < 4; i++) expect((await verifyPin('111111')).waitMs).toBe(0)
    const fifth = await verifyPin('111111')
    expect(fifth.ok).toBe(false)
    expect(fifth.waitMs).toBeGreaterThan(29_000)
    expect(fifth.waitMs).toBeLessThanOrEqual(30_000)
    // Even the right PIN is refused during the cooldown.
    expect((await verifyPin('246810')).ok).toBe(false)

    vi.useFakeTimers({ now: Date.now() + 31_000 })
    expect(getLockout()).toBe(0)
    const sixth = await verifyPin('111111')
    expect(sixth.waitMs).toBeGreaterThan(59_000) // 60s the second time
    vi.useFakeTimers({ now: Date.now() + 61_000 })
    expect((await verifyPin('246810')).ok).toBe(true)
    expect(getLockout()).toBe(0) // success resets the counter
  })

  it('saves settings patches without losing other fields', () => {
    saveLockSettings({ enabled: true })
    saveLockSettings({ autoLockSeconds: 0 })
    expect(getLockSettings()).toMatchObject({ enabled: true, autoLockSeconds: 0 })
  })
})
