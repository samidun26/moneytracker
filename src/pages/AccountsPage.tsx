import { useState } from 'react'
import { Plus } from 'lucide-react'
import { netWorth } from '@/domain/balances'
import { accountTypeLabel } from '@/db/seed'
import { useLedger } from '@/hooks/useLedger'
import { formatRp } from '@/lib/money'
import { cn } from '@/lib/cn'
import { Page, NavButton } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { IconBadge } from '@/components/ui/IconBadge'
import { EmptyState } from '@/components/ui/EmptyState'
import { Button } from '@/components/ui/Button'
import { AccountSheet } from '@/features/accounts/AccountSheet'

export function AccountsPage() {
  const L = useLedger()
  const [sheet, setSheet] = useState({ open: false, key: 0 })
  const open = () => setSheet((s) => ({ open: true, key: s.key + 1 }))
  const worth = netWorth(L.accounts, L.balances)
  const assets = L.activeAccounts.reduce((s, a) => s + Math.max(0, L.balances.get(a.id) ?? 0), 0)
  const debts = L.activeAccounts.reduce((s, a) => s + Math.min(0, L.balances.get(a.id) ?? 0), 0)
  const archived = L.accounts.filter((a) => a.archived)

  const row = (a: (typeof L.accounts)[number]) => {
    const bal = L.balances.get(a.id) ?? 0
    return (
      <ListRow
        key={a.id}
        to={`/accounts/${a.id}`}
        leading={<IconBadge icon={a.icon} color={a.color} />}
        title={a.name}
        subtitle={accountTypeLabel(a.type)}
        value={<span className={cn('tabular text-[16px]', bal < 0 ? 'text-negative' : 'text-label')}>{formatRp(bal)}</span>}
      />
    )
  }

  return (
    <Page
      title="Accounts"
      back={{ label: 'More', to: '/more' }}
      actions={
        <NavButton label="Add account" onClick={open}>
          <Plus className="size-6" strokeWidth={2.4} />
        </NavButton>
      }
    >
      {L.accounts.length === 0 ? (
        <EmptyState icon="🏦" title="No accounts" body="Add where your money lives: cash, bank, e-wallet, or credit card." action={<Button size="md" onClick={open}>Add account</Button>} />
      ) : (
        <>
          <div className="bg-surface mx-4 mb-8 rounded-[var(--radius-card)] p-4">
            <div className="text-label-2 text-[13px] font-medium">Net worth</div>
            <div className={cn('text-[34px] leading-[40px] font-bold tracking-tight', worth < 0 && 'text-negative')}>{formatRp(worth)}</div>
            <div className="text-label-2 mt-2 flex gap-4 text-[13px]">
              <span>
                Assets <span className="text-label font-medium">{formatRp(assets)}</span>
              </span>
              {debts < 0 && (
                <span>
                  Debts <span className="text-negative font-medium">{formatRp(debts)}</span>
                </span>
              )}
            </div>
          </div>
          <ListGroup header="Accounts">{L.activeAccounts.map(row)}</ListGroup>
          {archived.length > 0 && <ListGroup header="Archived">{archived.map(row)}</ListGroup>}
        </>
      )}
      <AccountSheet key={sheet.key} open={sheet.open} onClose={() => setSheet((s) => ({ ...s, open: false }))} />
    </Page>
  )
}
