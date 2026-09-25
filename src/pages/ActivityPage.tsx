import { useDeferredValue, useMemo, useState } from 'react'
import { Plus } from 'lucide-react'
import type { TxType } from '@/db/types'
import { useLedger } from '@/hooks/useLedger'
import { formatSigned } from '@/lib/money'
import { Page, NavButton } from '@/components/ui/Page'
import { SearchField } from '@/components/ui/SearchField'
import { SegmentedControl } from '@/components/ui/SegmentedControl'
import { EmptyState } from '@/components/ui/EmptyState'
import { TransactionList } from '@/features/transactions/TransactionList'
import { useComposer } from '@/features/transactions/Composer'

type Filter = 'all' | TxType

const FILTERS: Array<{ value: Filter; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'expense', label: 'Expenses' },
  { value: 'income', label: 'Income' },
  { value: 'transfer', label: 'Transfers' },
]

export function ActivityPage() {
  const { transactions, categoryById, accountById, ready } = useLedger()
  const compose = useComposer()
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<Filter>('all')
  const q = useDeferredValue(query.trim().toLowerCase())

  const filtered = useMemo(() => {
    const digits = q.replace(/[.\s]/g, '')
    return transactions.filter((t) => {
      if (filter !== 'all' && t.type !== filter) return false
      if (!q) return true
      const hay = [
        t.note,
        t.categoryId ? categoryById.get(t.categoryId)?.name : '',
        accountById.get(t.accountId)?.name,
        t.toAccountId ? accountById.get(t.toAccountId)?.name : '',
      ]
        .join(' ')
        .toLowerCase()
      return hay.includes(q) || (/^\d+$/.test(digits) && String(t.amount).includes(digits))
    })
  }, [transactions, filter, q, categoryById, accountById])

  const net = useMemo(
    () => filtered.reduce((s, t) => s + (t.type === 'income' ? t.amount : t.type === 'expense' ? -t.amount : 0), 0),
    [filtered],
  )

  return (
    <Page
      title="Activity"
      actions={
        <NavButton label="Add transaction" onClick={() => compose()}>
          <Plus className="size-6" strokeWidth={2.4} />
        </NavButton>
      }
      subheader={
        <div className="space-y-3">
          <SearchField value={query} onChange={setQuery} placeholder="Search notes, categories, amounts" />
          <SegmentedControl label="Filter" value={filter} onChange={setFilter} options={FILTERS} />
        </div>
      }
    >
      {(q || filter !== 'all') && filtered.length > 0 && (
        <p className="text-label-2 px-8 pb-3 text-[13px]">
          {filtered.length} {filtered.length === 1 ? 'result' : 'results'}
          {filter !== 'transfer' && ` · ${formatSigned(net)}`}
        </p>
      )}
      {filtered.length ? (
        <TransactionList transactions={filtered} />
      ) : (
        ready &&
        (transactions.length === 0 ? (
          <EmptyState icon="🧾" title="Nothing here yet" body="Tap + to log your first transaction." />
        ) : (
          <EmptyState icon="🔍" title="No matches" body="Try a different word, or search by amount, e.g. 25000." />
        ))
      )}
    </Page>
  )
}
