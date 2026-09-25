import { useState } from 'react'
import { Cloud, Database, Lock, Repeat, SunMoon, Tags, Target, Wallet, Smartphone } from 'lucide-react'
import { getLockSettings } from '@/security/lock'
import { useSyncState } from '@/sync/engine'
import { useLedger } from '@/hooks/useLedger'
import { getThemePref, setThemePref, type ThemePref } from '@/lib/theme'
import { timeAgo } from '@/lib/dates'
import { Page } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { GlyphBadge } from '@/components/ui/IconBadge'
import { SelectRow } from '@/components/ui/Fields'
import { isStandalone } from '@/components/InstallBanner'

const syncLabel: Record<string, string> = {
  disabled: 'Off',
  'signed-out': 'Signed out',
  syncing: 'Syncing…',
  offline: 'Offline',
  error: 'Needs attention',
}

export function MorePage() {
  const { accounts, budgets, rules } = useLedger()
  const sync = useSyncState()
  const lock = getLockSettings()
  const [theme, setTheme] = useState<ThemePref>(getThemePref)

  return (
    <Page title="More">
      <ListGroup header="Money">
        <ListRow to="/accounts" leading={<GlyphBadge color="blue"><Wallet className="size-[18px]" /></GlyphBadge>} title="Accounts" value={accounts.filter((a) => !a.archived).length || undefined} />
        <ListRow to="/budgets" leading={<GlyphBadge color="orange"><Target className="size-[18px]" /></GlyphBadge>} title="Budgets" value={budgets.length || undefined} />
        <ListRow to="/recurring" leading={<GlyphBadge color="purple"><Repeat className="size-[18px]" /></GlyphBadge>} title="Recurring" value={rules.filter((r) => r.active).length || undefined} />
        <ListRow to="/categories" leading={<GlyphBadge color="pink"><Tags className="size-[18px]" /></GlyphBadge>} title="Categories" />
      </ListGroup>

      <ListGroup header="Settings">
        <ListRow
          to="/more/sync"
          leading={<GlyphBadge color="cyan"><Cloud className="size-[18px]" /></GlyphBadge>}
          title="Sync & backup"
          value={sync.status === 'idle' ? (sync.lastSyncedAt ? timeAgo(sync.lastSyncedAt) : 'On') : syncLabel[sync.status]}
        />
        <ListRow
          to="/more/security"
          leading={<GlyphBadge color="green"><Lock className="size-[18px]" /></GlyphBadge>}
          title="App lock"
          value={lock.enabled ? (lock.biometricId ? 'Face ID' : 'PIN') : 'Off'}
        />
        <SelectRow
          leading={<GlyphBadge color="indigo"><SunMoon className="size-[18px]" /></GlyphBadge>}
          label="Appearance"
          value={theme}
          onChange={(t) => {
            setTheme(t)
            setThemePref(t)
          }}
          options={[
            { value: 'system', label: 'Automatic' },
            { value: 'light', label: 'Light' },
            { value: 'dark', label: 'Dark' },
          ]}
        />
        <ListRow to="/more/data" leading={<GlyphBadge color="gray"><Database className="size-[18px]" /></GlyphBadge>} title="Export & data" />
      </ListGroup>

      <ListGroup
        header="About"
        footer="Duit keeps your data on this device first. Cloud sync goes only to your own Supabase project."
      >
        {!isStandalone() && (
          <ListRow leading={<GlyphBadge color="teal"><Smartphone className="size-[18px]" /></GlyphBadge>} title="Install on iPhone" subtitle="Safari → Share → Add to Home Screen" />
        )}
        <ListRow title="Version" value={__APP_VERSION__} />
      </ListGroup>
    </Page>
  )
}
