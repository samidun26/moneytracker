import { useMemo, useState } from 'react'
import { useParams } from 'react-router-dom'
import { ArrowLeftRight, Minus, Plus } from 'lucide-react'
import { monthSummary } from '@/domain/balances'
import { accountTypeLabel } from '@/db/seed'
import { useLedger } from '@/hooks/useLedger'
import { useToday } from '@/hooks/useToday'
import { monthKey } from '@/lib/dates'
import { formatRp, formatRpCompact } from '@/lib/money'
import { cn } from '@/lib/cn'
import { Page, NavButton } from '@/components/ui/Page'
import { IconBadge } from '@/components/ui/IconBadge'
import { EmptyState } from '@/components/ui/EmptyState'
import { TransactionList } from '@/features/transactions/TransactionList'
import { useComposer } from '@/features/transactions/Composer'
import { AccountSheet } from '@/features/accounts/AccountSheet'

export function AccountDetailPage() {
  const { id = '' } = useParams()
  const L = useLedger()
  const today = useToday()
  const compose = useComposer()
  const [sheet, setSheet] = useState({ open: false, key: 0 })
  const account = L.accountById.get(id)
  const txs = useMemo(() => L.transactions.filter((t) => t.accountId === id || t.toAccountId === id), [L.transactions, id])
  const month = useMemo(() => monthSummary(txs.filter((t) => t.type !== 'transfer'), monthKey(today)), [txs, today])

  if (!account) {
    return (
      <Page title="Account" back={{ label: 'Accounts', to: '/accounts' }}>
        {L.ready && <EmptyState icon="🤷" title="Account not found" body="It may have been deleted on another device." />}
      </Page>
    )
  }
  const bal = L.balances.get(id) ?? 0

  return (
    <Page
      title={account.name}
      back={{ label: 'Accounts', to: '/accounts' }}
      actions={
        <NavButton label="Edit account" onClick={() => setSheet((s) => ({ open: true, key: s.key + 1 }))}>
          Edit
        </NavButton>
      }
    >
      <div className="bg-surface mx-4 mb-4 rounded-[var(--radius-card)] p-4">
        <div className="flex items-center gap-3">
          <IconBadge icon={account.icon} color={account.color} size="lg" />
          <div className="min-w-0">
            <div className="text-label-2 text-[13px]">
              {accountTypeLabel(account.type)}
              {account.archived && ' · Archived'}
            </div>
            <div className={cn('text-[28px] leading-8 font-bold tracking-tight', bal < 0 && 'text-negative')}>{formatRp(bal)}</div>
          </div>
        </div>
        <div className="text-label-2 mt-3 flex gap-4 text-[13px]">
          <span>
            In this month <span className="text-positive font-medium">+{formatRpCompact(month.income)}</span>
          </span>
          <span>
            Out <span className="text-label font-medium">−{formatRpCompact(month.expense)}</span>
          </span>
        </div>
      </div>
      <div className="mx-4 mb-8 grid grid-cols-3 gap-2">
        {[
          { label: 'Expense', icon: Minus, type: 'expense' as const },
          { label: 'Income', icon: Plus, type: 'income' as const },
          { label: 'Transfer', icon: ArrowLeftRight, type: 'transfer' as const },
        ].map((b) => (
          <button
            key={b.type}
            type="button"
            onClick={() => compose({ type: b.type, accountId: id })}
            className="press bg-surface text-tint flex flex-col items-center gap-1 rounded-[12px] py-2.5 text-[13px] font-medium"
          >
            <b.icon className="size-5" strokeWidth={2.2} />
            {b.label}
          </button>
        ))}
      </div>
      {txs.length ? (
        <TransactionList transactions={txs} perspective={id} />
      ) : (
        <EmptyState icon="🧾" title="No transactions" body={`Nothing has moved through ${account.name} yet.`} />
      )}
      <AccountSheet key={sheet.key} open={sheet.open} account={account} onClose={() => setSheet((s) => ({ ...s, open: false }))} />
    </Page>
  )
}
