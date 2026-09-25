import { Cloud, CloudAlert, CloudOff, RefreshCw } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useSyncState } from '@/sync/engine'

/** Small nav-bar glyph: only visible when sync is set up. */
export function SyncIndicator() {
  const s = useSyncState()
  if (s.status === 'disabled') return null
  const map = {
    'signed-out': { icon: CloudOff, label: 'Sync: signed out', cls: 'text-label-2' },
    idle: { icon: Cloud, label: 'Sync: up to date', cls: 'text-label-2' },
    syncing: { icon: RefreshCw, label: 'Syncing…', cls: 'text-tint animate-spin' },
    offline: { icon: CloudOff, label: 'Offline — changes are saved on this device', cls: 'text-label-2' },
    error: { icon: CloudAlert, label: `Sync problem: ${s.error ?? ''}`, cls: 'text-negative' },
  } as const
  const { icon: Icon, label, cls } = map[s.status]
  return (
    <Link to="/more/sync" aria-label={label} title={label} className="press flex size-9 items-center justify-center rounded-full">
      <Icon className={`size-[22px] ${cls}`} strokeWidth={2} style={s.status === 'syncing' ? { animationDuration: '1.2s' } : undefined} />
    </Link>
  )
}
