import { useMemo, useState } from 'react'
import type { Transaction } from '@/db/types'
import { useToday } from '@/hooks/useToday'
import { formatDayLabel, formatMonth, monthKey } from '@/lib/dates'
import { formatSigned } from '@/lib/money'
import { signedFor } from '@/domain/balances'
import { TransactionRow } from './TransactionRow'

const PAGE_DAYS = 45

/** Transactions grouped by day with a daily net, and month dividers. Renders progressively. */
export function TransactionList({
  transactions,
  perspective,
  showMonths = true,
}: {
  transactions: Transaction[]
  perspective?: string
  showMonths?: boolean
}) {
  const today = useToday()
  const [limit, setLimit] = useState(PAGE_DAYS)

  const days = useMemo(() => {
    const groups: Array<{ date: string; items: Transaction[]; net: number }> = []
    for (const t of transactions) {
      let g = groups[groups.length - 1]
      if (!g || g.date !== t.date) {
        g = { date: t.date, items: [], net: 0 }
        groups.push(g)
      }
      g.items.push(t)
      g.net += perspective ? signedFor(t, perspective) : t.type === 'income' ? t.amount : t.type === 'expense' ? -t.amount : 0
    }
    return groups
  }, [transactions, perspective])

  const visible = days.slice(0, limit)

  return (
    <div>
      {visible.map((day, i) => {
        const newMonth = showMonths && (i === 0 || monthKey(visible[i - 1].date) !== monthKey(day.date))
        return (
          <div key={day.date}>
            {newMonth && i > 0 && (
              <h3 className="px-8 pt-3 pb-3 text-[20px] font-bold tracking-tight">{formatMonth(monthKey(day.date))}</h3>
            )}
            <section className="mx-4 mb-5">
              <div className="flex items-baseline justify-between px-4 pb-1.5">
                <h4 className="text-label-2 text-[13px] font-semibold uppercase tracking-[0.02em]">
                  {formatDayLabel(day.date, today)}
                </h4>
                {day.net !== 0 && <span className="text-label-2 tabular text-[13px]">{formatSigned(day.net)}</span>}
              </div>
              <div className="bg-surface overflow-hidden rounded-[var(--radius-card)]">
                {day.items.map((t) => (
                  <TransactionRow key={t.id} tx={t} perspective={perspective} />
                ))}
              </div>
            </section>
          </div>
        )
      })}
      {days.length > limit && (
        <div className="flex justify-center pb-6">
          <button
            type="button"
            onClick={() => setLimit((l) => l + PAGE_DAYS)}
            className="press bg-surface text-tint rounded-full px-5 py-2 text-[15px] font-medium"
          >
            Show earlier
          </button>
        </div>
      )}
    </div>
  )
}
