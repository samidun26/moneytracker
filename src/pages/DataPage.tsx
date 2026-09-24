import { useEffect, useRef, useState } from 'react'
import { FileJson, FileSpreadsheet, Upload } from 'lucide-react'
import { createBackup, eraseLocalData, importBackup, saveFile, transactionsToCSV } from '@/domain/backup'
import { resetCursors } from '@/sync/engine'
import { useLedger } from '@/hooks/useLedger'
import { todayISO } from '@/lib/dates'
import { writeString } from '@/lib/storage'
import { Page } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { GlyphBadge } from '@/components/ui/IconBadge'
import { useToast } from '@/components/ui/Toast'
import { useConfirm } from '@/components/ui/Confirm'

export function DataPage() {
  const L = useLedger()
  const toast = useToast()
  const confirm = useConfirm()
  const fileInput = useRef<HTMLInputElement>(null)
  const [persisted, setPersisted] = useState<boolean | null>(null)

  useEffect(() => {
    void navigator.storage?.persisted?.().then(setPersisted)
  }, [])

  const exportCSV = async () => {
    const csv = transactionsToCSV(L.transactions, L.accounts, L.categories)
    await saveFile(`duit-transactions-${todayISO()}.csv`, csv, 'text/csv')
  }

  const exportJSON = async () => {
    const backup = await createBackup()
    await saveFile(`duit-backup-${todayISO()}.json`, JSON.stringify(backup, null, 2), 'application/json')
  }

  const onImport = async (file: File) => {
    try {
      const r = await importBackup(JSON.parse(await file.text()))
      toast({ message: `Restored: ${r.added} added, ${r.updated} updated` })
    } catch (e) {
      toast({ message: (e as Error).message || 'Could not read that file', tone: 'error' })
    }
  }

  const erase = async () => {
    const ok = await confirm({
      title: 'Erase all data on this device?',
      message: 'If you use sync, your cloud copy is kept and downloads again when you sign in. Otherwise, export a backup first.',
      confirmLabel: 'Erase this device',
      destructive: true,
    })
    if (!ok) return
    await eraseLocalData()
    resetCursors()
    writeString('duit.onboarded', null)
    location.replace('/')
  }

  return (
    <Page title="Export & data" back={{ label: 'More', to: '/more' }}>
      <ListGroup header="Export" footer="CSV opens in Numbers, Excel or Google Sheets. The backup file can be restored here on any device.">
        <ListRow leading={<GlyphBadge color="green"><FileSpreadsheet className="size-[18px]" /></GlyphBadge>} title="Transactions (CSV)" subtitle={`${L.transactions.length} transactions`} onClick={exportCSV} chevron={false} />
        <ListRow leading={<GlyphBadge color="blue"><FileJson className="size-[18px]" /></GlyphBadge>} title="Full backup (JSON)" subtitle="Accounts, categories, budgets, recurring, transactions" onClick={exportJSON} chevron={false} />
      </ListGroup>

      <ListGroup header="Restore" footer="Merges with what’s here. Newer edits always win, so restoring never overwrites recent changes.">
        <ListRow leading={<GlyphBadge color="orange"><Upload className="size-[18px]" /></GlyphBadge>} title="Restore from backup…" onClick={() => fileInput.current?.click()} chevron={false} />
      </ListGroup>
      <input
        ref={fileInput}
        type="file"
        accept="application/json,.json"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0]
          if (f) void onImport(f)
          e.target.value = ''
        }}
      />

      <ListGroup header="Storage">
        <ListRow title="Saved on this device" value={`${L.transactions.length + L.accounts.length + L.categories.length + L.budgets.length + L.rules.length} records`} />
        {persisted != null && <ListRow title="Protected from cleanup" value={persisted ? 'Yes' : 'Not yet'} />}
      </ListGroup>

      <ListGroup>
        <button type="button" onClick={erase} className="row-press text-negative h-11 w-full text-[17px]">
          Erase data on this device
        </button>
      </ListGroup>
    </Page>
  )
}
