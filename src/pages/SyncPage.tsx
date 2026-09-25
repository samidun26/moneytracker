import { useState } from 'react'
import { useLiveQuery } from 'dexie-react-hooks'
import { ExternalLink, RefreshCw } from 'lucide-react'
import { countDirty } from '@/sync/merge'
import { getSupabaseConfig, isValidSupabaseUrl, saveDeviceConfig } from '@/sync/config'
import { reconfigureSync, signIn, signOut, signUp, syncNow, useSyncState } from '@/sync/engine'
import { db } from '@/db/db'
import { timeAgo } from '@/lib/dates'
import { Page } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { PlainInputRow } from '@/components/ui/Fields'
import { Button } from '@/components/ui/Button'
import { useToast } from '@/components/ui/Toast'
import { useConfirm } from '@/components/ui/Confirm'

const SETUP_URL = 'https://github.com/samidun26/moneytracker#cloud-sync-supabase'

export function SyncPage() {
  const sync = useSyncState()
  const { config, source } = getSupabaseConfig()
  const pending = useLiveQuery(countDirty, [], 0)
  const records = useLiveQuery(() => db.transactions.count(), [], 0)

  return (
    <Page title="Sync & backup" back={{ label: 'More', to: '/more' }}>
      {!config ? (
        <ConnectProject />
      ) : !sync.userId ? (
        <SignIn source={source} />
      ) : (
        <SignedIn pending={pending ?? 0} records={records ?? 0} source={source} />
      )}
    </Page>
  )
}

function ConnectProject() {
  const toast = useToast()
  const [url, setUrl] = useState('')
  const [key, setKey] = useState('')
  const [busy, setBusy] = useState(false)
  const valid = isValidSupabaseUrl(url) && key.trim().length > 20

  return (
    <>
      <div className="mx-4 mb-6 text-[15px] leading-[21px]">
        <p className="text-label-2">
          Duit works fully offline. Connect a free <strong className="text-label">Supabase</strong> project to back up your data and use the same data on your iPhone and laptop.
        </p>
        <a href={SETUP_URL} target="_blank" rel="noreferrer" className="text-tint mt-2 inline-flex items-center gap-1 font-medium">
          5-minute setup guide <ExternalLink className="size-4" />
        </a>
      </div>
      <ListGroup header="Supabase project" footer="Settings → API in your Supabase dashboard. The publishable (anon) key is safe to use in the app; row-level security keeps your data private.">
        <PlainInputRow value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://xxxx.supabase.co" inputMode="url" autoCapitalize="off" autoCorrect="off" spellCheck={false} aria-label="Project URL" />
        <PlainInputRow value={key} onChange={(e) => setKey(e.target.value)} placeholder="Publishable / anon key" autoCapitalize="off" autoCorrect="off" spellCheck={false} aria-label="API key" />
      </ListGroup>
      <div className="mx-4">
        <Button
          block
          disabled={!valid || busy}
          onClick={async () => {
            setBusy(true)
            saveDeviceConfig({ url, key })
            await reconfigureSync()
            setBusy(false)
            toast({ message: 'Project connected' })
          }}
        >
          Connect
        </Button>
      </div>
    </>
  )
}

function SignIn({ source }: { source: 'env' | 'device' | null }) {
  const toast = useToast()
  const [mode, setMode] = useState<'in' | 'up'>('in')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [checkEmail, setCheckEmail] = useState(false)

  const submit = async () => {
    setBusy(true)
    setError(null)
    try {
      if (mode === 'in') {
        await signIn(email, password)
        toast({ message: 'Signed in. Syncing…' })
      } else {
        const needsConfirm = await signUp(email, password)
        if (needsConfirm) setCheckEmail(true)
        else toast({ message: 'Account created. Syncing…' })
      }
    } catch (e) {
      setError((e as Error).message)
    } finally {
      setBusy(false)
    }
  }

  if (checkEmail)
    return (
      <div className="mx-4 text-center">
        <p className="mb-2 text-[40px]">📬</p>
        <p className="text-[20px] font-semibold">Confirm your email</p>
        <p className="text-label-2 mt-2 text-[15px]">
          We sent a link to <strong className="text-label">{email}</strong>. Open it, then come back here and sign in.
        </p>
        <Button className="mt-6" variant="tinted" onClick={() => (setCheckEmail(false), setMode('in'))}>
          Back to sign in
        </Button>
      </div>
    )

  return (
    <>
      <p className="text-label-2 mx-8 mb-4 text-[15px]">
        {mode === 'in' ? 'Sign in to sync this device.' : 'Create your sync account. You only need one, and you can use it on all your devices.'}
      </p>
      <ListGroup footer={error ? <span className="text-negative">{error}</span> : mode === 'up' ? 'At least 8 characters.' : undefined}>
        <PlainInputRow type="email" autoComplete="email" inputMode="email" autoCapitalize="off" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" aria-label="Email" />
        <PlainInputRow
          type="password"
          autoComplete={mode === 'in' ? 'current-password' : 'new-password'}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && void submit()}
          placeholder="Password"
          aria-label="Password"
        />
      </ListGroup>
      <div className="mx-4 space-y-3">
        <Button block disabled={busy || !email.includes('@') || password.length < (mode === 'up' ? 8 : 1)} onClick={submit}>
          {busy ? 'Please wait…' : mode === 'in' ? 'Sign in' : 'Create account'}
        </Button>
        <Button block variant="plain" onClick={() => (setMode(mode === 'in' ? 'up' : 'in'), setError(null))}>
          {mode === 'in' ? 'New here? Create an account' : 'Have an account? Sign in'}
        </Button>
      </div>
      {source === 'device' && <DisconnectProject />}
    </>
  )
}

function SignedIn({ pending, records, source }: { pending: number; records: number; source: 'env' | 'device' | null }) {
  const sync = useSyncState()
  const confirm = useConfirm()
  const status =
    sync.status === 'syncing'
      ? 'Syncing…'
      : sync.status === 'offline'
        ? 'Offline. Changes are saved on this device.'
        : sync.status === 'error'
          ? sync.error
          : 'Up to date'

  return (
    <>
      <ListGroup header="Status" footer="Sync runs automatically when you open the app, after changes, and every minute while it’s open.">
        <ListRow title="Account" value={sync.email} />
        <ListRow title="Status" value={<span className={sync.status === 'error' ? 'text-negative' : undefined}>{status}</span>} />
        <ListRow title="Last synced" value={sync.lastSyncedAt ? timeAgo(sync.lastSyncedAt) : 'Never'} />
        <ListRow title="Waiting to upload" value={pending ? `${pending} change${pending === 1 ? '' : 's'}` : 'Nothing'} />
        <ListRow title="Transactions on this device" value={records} />
      </ListGroup>
      <div className="mx-4 mb-8">
        <Button block variant="tinted" disabled={sync.status === 'syncing'} onClick={() => void syncNow()}>
          <RefreshCw className={`size-5 ${sync.status === 'syncing' ? 'animate-spin' : ''}`} /> Sync now
        </Button>
      </div>
      <ListGroup footer="Signing out keeps your data on this device. It stops syncing until you sign in again.">
        <button
          type="button"
          className="row-press text-negative h-11 w-full text-[17px]"
          onClick={async () => {
            const ok = await confirm({ title: 'Sign out of sync?', message: pending ? `${pending} change(s) haven’t been uploaded yet.` : undefined, confirmLabel: 'Sign out', destructive: true })
            if (ok) await signOut()
          }}
        >
          Sign out
        </button>
      </ListGroup>
      {source === 'device' && <DisconnectProject />}
    </>
  )
}

function DisconnectProject() {
  const confirm = useConfirm()
  return (
    <div className="mt-6 flex justify-center">
      <button
        type="button"
        className="text-label-2 text-[13px] underline"
        onClick={async () => {
          const ok = await confirm({ title: 'Disconnect Supabase project?', message: 'Your local data stays. You can reconnect anytime.', confirmLabel: 'Disconnect', destructive: true })
          if (!ok) return
          await signOut()
          saveDeviceConfig(null)
          await reconfigureSync()
        }}
      >
        Disconnect project
      </button>
    </div>
  )
}
