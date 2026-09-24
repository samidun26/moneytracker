import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { ScanFace } from 'lucide-react'
import { getLockout, getLockSettings, PIN_LENGTH, verifyBiometric, verifyPin } from './lock'
import { PinPad } from './PinPad'

interface LockApi {
  locked: boolean
  lockNow: () => void
  /** Re-read settings after they change in Security settings */
  refresh: () => void
}

const LockContext = createContext<LockApi>({ locked: false, lockNow: () => {}, refresh: () => {} })

export function useLock() {
  return useContext(LockContext)
}

export function LockProvider({ children }: { children: ReactNode }) {
  const [settings, setSettings] = useState(getLockSettings)
  const [locked, setLocked] = useState(() => getLockSettings().enabled && !!getLockSettings().pinHash)
  const hiddenAt = useRef<number | null>(null)

  const refresh = useCallback(() => setSettings(getLockSettings()), [])
  const lockNow = useCallback(() => {
    const s = getLockSettings()
    if (s.enabled && s.pinHash) setLocked(true)
  }, [])

  useEffect(() => {
    const onVis = () => {
      const s = getLockSettings()
      if (!s.enabled || !s.pinHash) return
      if (document.visibilityState === 'hidden') {
        hiddenAt.current = Date.now()
        if (s.autoLockSeconds === 0) setLocked(true)
      } else if (hiddenAt.current && Date.now() - hiddenAt.current >= s.autoLockSeconds * 1000) {
        setLocked(true)
      }
    }
    document.addEventListener('visibilitychange', onVis)
    return () => document.removeEventListener('visibilitychange', onVis)
  }, [])

  return (
    <LockContext.Provider value={{ locked, lockNow, refresh }}>
      <div inert={locked} aria-hidden={locked}>
        {children}
      </div>
      {locked && createPortal(<LockScreen biometric={!!settings.biometricId} onUnlock={() => setLocked(false)} />, document.body)}
    </LockContext.Provider>
  )
}

function LockScreen({ biometric, onUnlock }: { biometric: boolean; onUnlock: () => void }) {
  const [pin, setPin] = useState('')
  const [error, setError] = useState(false)
  const [wait, setWait] = useState(getLockout)
  const tried = useRef(false)

  const tryBiometric = useCallback(async () => {
    if (await verifyBiometric()) onUnlock()
  }, [onUnlock])

  // Offer Face ID immediately; if iOS requires a tap first, the button is right there.
  useEffect(() => {
    if (biometric && !tried.current) {
      tried.current = true
      void tryBiometric()
    }
  }, [biometric, tryBiometric])

  useEffect(() => {
    if (wait <= 0) return
    const t = setInterval(() => setWait(getLockout()), 500)
    return () => clearInterval(t)
  }, [wait])

  const onChange = async (v: string) => {
    setError(false)
    setPin(v)
    if (v.length === PIN_LENGTH) {
      const res = await verifyPin(v)
      if (res.ok) return onUnlock()
      setError(true)
      setWait(res.waitMs)
      setTimeout(() => setPin(''), 350)
    }
  }

  return (
    <div className="bg-bg fixed inset-0 z-[100] flex flex-col items-center justify-center px-6 pt-safe pb-safe animate-[fade-in_150ms_ease-out]" role="dialog" aria-modal="true" aria-label="Duit is locked">
      <img src="/favicon.svg" alt="" className="mb-4 size-14" />
      <p className="mb-8 text-[20px] font-semibold">{wait > 0 ? `Try again in ${Math.ceil(wait / 1000)}s` : 'Enter PIN'}</p>
      <PinPad
        value={pin}
        onChange={onChange}
        error={error}
        disabled={wait > 0}
        extraKey={
          biometric ? (
            <button type="button" onClick={tryBiometric} aria-label="Unlock with Face ID" className="text-tint flex size-[76px] items-center justify-center">
              <ScanFace className="size-9" strokeWidth={1.6} />
            </button>
          ) : null
        }
      />
    </div>
  )
}
