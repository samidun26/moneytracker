import { useEffect, useState } from 'react'
import { ScanFace } from 'lucide-react'
import {
  biometricLabel,
  getLockSettings,
  isBiometricAvailable,
  PIN_LENGTH,
  registerBiometric,
  saveLockSettings,
  setPin,
} from '@/security/lock'
import { useLock } from '@/security/LockProvider'
import { PinPad } from '@/security/PinPad'
import { Page } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { SelectRow, ToggleRow } from '@/components/ui/Fields'
import { GlyphBadge } from '@/components/ui/IconBadge'
import { Sheet, SheetButton } from '@/components/ui/Sheet'
import { useToast } from '@/components/ui/Toast'

export function SecurityPage() {
  const toast = useToast()
  const { refresh } = useLock()
  const [s, setS] = useState(getLockSettings)
  const [bioAvailable, setBioAvailable] = useState(false)
  const [pinSheet, setPinSheet] = useState<{ open: boolean; key: number; enabling: boolean }>({ open: false, key: 0, enabling: false })
  const bio = biometricLabel()

  useEffect(() => {
    void isBiometricAvailable().then(setBioAvailable)
  }, [])

  const update = (patch: Parameters<typeof saveLockSettings>[0]) => {
    setS(saveLockSettings(patch))
    refresh()
  }

  const toggleLock = (on: boolean) => {
    if (on) setPinSheet((p) => ({ open: true, key: p.key + 1, enabling: true }))
    else update({ enabled: false, biometricId: null })
  }

  const toggleBio = async (on: boolean) => {
    if (!on) return update({ biometricId: null })
    try {
      await registerBiometric()
      setS(getLockSettings())
      refresh()
      toast({ message: `${bio} is on` })
    } catch (e) {
      toast({ message: (e as Error).name === 'NotAllowedError' ? `${bio} setup was cancelled` : `Couldn’t set up ${bio}`, tone: 'error' })
    }
  }

  return (
    <Page title="App lock" back={{ label: 'More', to: '/more' }}>
      <ListGroup footer="Asks for Face ID or your PIN when you open Duit, so no one can browse your finances on your unlocked phone. It’s a privacy screen; your iPhone’s own encryption protects the stored data.">
        <ToggleRow label="Require unlock" checked={s.enabled} onChange={toggleLock} />
      </ListGroup>

      {s.enabled && (
        <>
          <ListGroup footer={bioAvailable ? `Uses a passkey on this device that only unlocks Duit. Your PIN always works as a backup.` : `${bio} isn’t available here. Install Duit to your Home Screen on an iPhone with Face ID.`}>
            <ToggleRow
              leading={<GlyphBadge color="green"><ScanFace className="size-[18px]" /></GlyphBadge>}
              label={`Unlock with ${bio}`}
              checked={!!s.biometricId}
              onChange={toggleBio}
              disabled={!bioAvailable}
            />
          </ListGroup>
          <ListGroup>
            <SelectRow
              label="Lock after"
              value={String(s.autoLockSeconds)}
              onChange={(v) => update({ autoLockSeconds: Number(v) })}
              options={[
                { value: '0', label: 'Immediately' },
                { value: '60', label: '1 minute' },
                { value: '300', label: '5 minutes' },
                { value: '900', label: '15 minutes' },
              ]}
            />
            <ListRow title="Change PIN" tinted chevron={false} onClick={() => setPinSheet((p) => ({ open: true, key: p.key + 1, enabling: false }))} />
          </ListGroup>
        </>
      )}

      <PinSetupSheet
        key={pinSheet.key}
        open={pinSheet.open}
        onClose={() => setPinSheet((p) => ({ ...p, open: false }))}
        onDone={async (pin) => {
          await setPin(pin)
          update({ enabled: true })
          setPinSheet((p) => ({ ...p, open: false }))
          toast({ message: pinSheet.enabling ? 'App lock is on' : 'PIN changed' })
        }}
      />
    </Page>
  )
}

function PinSetupSheet({ open, onClose, onDone }: { open: boolean; onClose: () => void; onDone: (pin: string) => void }) {
  const [first, setFirst] = useState<string | null>(null)
  const [value, setValue] = useState('')
  const [error, setError] = useState(false)

  const onChange = (v: string) => {
    setError(false)
    setValue(v)
    if (v.length < PIN_LENGTH) return
    if (!first) {
      setTimeout(() => {
        setFirst(v)
        setValue('')
      }, 150)
    } else if (v === first) {
      onDone(v)
    } else {
      setError(true)
      setTimeout(() => {
        setFirst(null)
        setValue('')
      }, 450)
    }
  }

  return (
    <Sheet open={open} onClose={onClose} tone="plain" leading={<SheetButton onClick={onClose}>Cancel</SheetButton>} title="Set PIN">
      <div className="flex flex-1 flex-col items-center justify-center overflow-y-auto pt-4 pb-[max(env(safe-area-inset-bottom),24px)]">
        <p className="mb-2 text-[20px] font-semibold">{first ? 'Confirm your PIN' : `Choose a ${PIN_LENGTH}-digit PIN`}</p>
        <p className="text-label-2 mb-8 h-5 text-[15px]">{error ? 'PINs didn’t match. Try again.' : 'Backup for when Face ID can’t be used.'}</p>
        <PinPad value={value} onChange={onChange} error={error} />
      </div>
    </Sheet>
  )
}
