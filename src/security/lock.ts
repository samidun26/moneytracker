import { readJSON, writeJSON } from '@/lib/storage'

/**
 * App lock — a privacy screen for when someone picks up your unlocked phone.
 * Not encryption: data at rest is protected by iOS device encryption.
 *
 * Face ID uses a WebAuthn *platform* credential with userVerification
 * "required": the OS only returns an assertion after a successful biometric
 * (or device passcode) check, and we additionally verify the UV flag.
 * Settings are device-local and never synced.
 */

export interface LockSettings {
  enabled: boolean
  pinHash: string | null
  pinSalt: string | null
  biometricId: string | null
  /** Re-lock after the app has been in the background this long. 0 = immediately. */
  autoLockSeconds: number
}

const KEY = 'duit.lock'
const ATTEMPTS_KEY = 'duit.lock.attempts'
export const PIN_LENGTH = 6
const ITERATIONS = 210_000

const DEFAULTS: LockSettings = {
  enabled: false,
  pinHash: null,
  pinSalt: null,
  biometricId: null,
  autoLockSeconds: 60,
}

export function getLockSettings(): LockSettings {
  return readJSON(KEY, DEFAULTS)
}

export function saveLockSettings(patch: Partial<LockSettings>): LockSettings {
  const next = { ...getLockSettings(), ...patch }
  writeJSON(KEY, next)
  return next
}

// ── base64url helpers ──────────────────────────────────────────────────────
function toB64url(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf)
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function fromB64url(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4)
  const bin = atob(b64)
  const out = new Uint8Array(new ArrayBuffer(bin.length))
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

function randomBytes(n: number): Uint8Array<ArrayBuffer> {
  return crypto.getRandomValues(new Uint8Array(new ArrayBuffer(n)))
}

// ── PIN ────────────────────────────────────────────────────────────────────
async function hashPin(pin: string, salt: Uint8Array<ArrayBuffer>): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(pin), 'PBKDF2', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt, iterations: ITERATIONS }, key, 256)
  return toB64url(bits)
}

export async function setPin(pin: string): Promise<void> {
  const salt = randomBytes(16)
  const pinHash = await hashPin(pin, salt)
  saveLockSettings({ pinHash, pinSalt: toB64url(salt) })
}

interface Attempts {
  count: number
  lockedUntil: number
}

export function getLockout(now = Date.now()): number {
  const a = readJSON<Attempts>(ATTEMPTS_KEY, { count: 0, lockedUntil: 0 })
  return Math.max(0, a.lockedUntil - now)
}

/** Verifies a PIN with escalating cooldowns after 5 failures (30s, 60s, 120s…). */
export async function verifyPin(pin: string): Promise<{ ok: boolean; waitMs: number }> {
  const wait = getLockout()
  if (wait > 0) return { ok: false, waitMs: wait }
  const s = getLockSettings()
  if (!s.pinHash || !s.pinSalt) return { ok: false, waitMs: 0 }
  const ok = (await hashPin(pin, fromB64url(s.pinSalt))) === s.pinHash
  const a = readJSON<Attempts>(ATTEMPTS_KEY, { count: 0, lockedUntil: 0 })
  if (ok) {
    writeJSON(ATTEMPTS_KEY, { count: 0, lockedUntil: 0 })
    return { ok, waitMs: 0 }
  }
  const count = a.count + 1
  const lockedUntil = count >= 5 ? Date.now() + 30_000 * 2 ** Math.min(count - 5, 5) : 0
  writeJSON(ATTEMPTS_KEY, { count, lockedUntil })
  return { ok, waitMs: Math.max(0, lockedUntil - Date.now()) }
}

// ── Face ID / Touch ID via WebAuthn ────────────────────────────────────────
export async function isBiometricAvailable(): Promise<boolean> {
  try {
    return (
      typeof window !== 'undefined' &&
      !!window.PublicKeyCredential &&
      window.isSecureContext &&
      (await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable())
    )
  } catch {
    return false
  }
}

export function biometricLabel(): string {
  const ua = navigator.userAgent
  if (/iPhone|iPad|iPod/.test(ua)) return 'Face ID'
  if (/Macintosh/.test(ua)) return 'Touch ID'
  if (/Android/.test(ua)) return 'Fingerprint'
  return 'Biometrics'
}

/** Must be called from a user gesture (tap). Creates a device passkey used only to unlock this app. */
export async function registerBiometric(): Promise<void> {
  const cred = (await navigator.credentials.create({
    publicKey: {
      challenge: randomBytes(32),
      rp: { name: 'Duit' },
      user: { id: randomBytes(16), name: 'Duit app lock', displayName: 'Duit app lock' },
      pubKeyCredParams: [
        { type: 'public-key', alg: -7 },
        { type: 'public-key', alg: -257 },
      ],
      authenticatorSelection: {
        authenticatorAttachment: 'platform',
        userVerification: 'required',
        residentKey: 'preferred',
      },
      attestation: 'none',
      timeout: 60_000,
    },
  })) as PublicKeyCredential | null
  if (!cred) throw new Error('Face ID setup was cancelled.')
  saveLockSettings({ biometricId: toB64url(cred.rawId) })
}

export async function verifyBiometric(): Promise<boolean> {
  const { biometricId } = getLockSettings()
  if (!biometricId) return false
  try {
    const assertion = (await navigator.credentials.get({
      publicKey: {
        challenge: randomBytes(32),
        allowCredentials: [{ type: 'public-key', id: fromB64url(biometricId), transports: ['internal'] }],
        userVerification: 'required',
        timeout: 60_000,
      },
    })) as PublicKeyCredential | null
    if (!assertion) return false
    const authData = new Uint8Array((assertion.response as AuthenticatorAssertionResponse).authenticatorData)
    const USER_VERIFIED = 0x04
    return (authData[32] & USER_VERIFIED) !== 0
  } catch {
    return false
  }
}
