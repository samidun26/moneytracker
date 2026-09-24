import { useMemo, useState } from 'react'
import { Plus } from 'lucide-react'
import type { RecurringRule } from '@/db/types'
import { describeSchedule, monthlyEquivalent, nextDueDate, upcomingOccurrences } from '@/domain/recurring'
import { useLedger } from '@/hooks/useLedger'
import { useToday } from '@/hooks/useToday'
import { formatDayPhrase } from '@/lib/dates'
import { formatNumber } from '@/lib/money'
import { Page, NavButton } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { StatTile } from '@/components/ui/StatTile'
import { EmptyState } from '@/components/ui/EmptyState'
import { Button } from '@/components/ui/Button'
import { IconBadge } from '@/components/ui/IconBadge'
import { OccurrenceRow } from '@/features/recurring/OccurrenceRow'
import { RecurringSheet } from '@/features/recurring/RecurringSheet'

export function RecurringPage() {
  const L = useLedger()
  const today = useToday()
  const [sheet, setSheet] = useState<{ open: boolean; rule?: RecurringRule; key: number }>({ open: false, key: 0 })
  const open = (rule?: RecurringRule) => setSheet((s) => ({ open: true, rule, key: s.key + 1 }))

  const occurrences = useMemo(() => upcomingOccurrences(L.rules, today, 30), [L.rules, today])
  const due = occurrences.filter((o) => o.status === 'due')
  const upcoming = occurrences.filter((o) => o.status === 'upcoming').slice(0, 8)
  const active = L.rules.filter((r) => r.active)
  const fixedOut = active.filter((r) => r.type === 'expense').reduce((s, r) => s + monthlyEquivalent(r), 0)
  const fixedIn = active.filter((r) => r.type === 'income').reduce((s, r) => s + monthlyEquivalent(r), 0)

  return (
    <Page
      title="Recurring"
      back={{ label: 'More', to: '/more' }}
      actions={
        <NavButton label="Add recurring" onClick={() => open()}>
          <Plus className="size-6" strokeWidth={2.4} />
        </NavButton>
      }
    >
      {L.rules.length === 0 ? (
        <EmptyState
          icon="🔁"
          title="Automate the regulars"
          body="Rent, salary, Netflix, BPJS, phone credit. Add them once and Duit logs or reminds you each time."
          action={<Button size="md" onClick={() => open()}>Add recurring</Button>}
        />
      ) : (
        <>
          <div className="mx-4 mb-8 grid grid-cols-2 gap-3">
            <StatTile label="Fixed costs / month" money={fixedOut} delta={`${active.filter((r) => r.type === 'expense').length} bills & subs`} />
            <StatTile label="Recurring income" money={fixedIn} valueClassName={fixedIn ? 'text-positive' : ''} delta={fixedIn ? `${Math.round((fixedOut / fixedIn) * 100)}% to fixed costs` : 'Add your salary'} />
          </div>

          {due.length > 0 && (
            <ListGroup header="Needs confirmation">
              {due.map((o) => (
                <OccurrenceRow key={`${o.rule.id}-${o.date}`} o={o} onOpen={() => open(o.rule)} />
              ))}
            </ListGroup>
          )}

          {upcoming.length > 0 && (
            <ListGroup header="Next 30 days">
              {upcoming.map((o) => (
                <OccurrenceRow key={`${o.rule.id}-${o.date}`} o={o} onOpen={() => open(o.rule)} />
              ))}
            </ListGroup>
          )}

          <ListGroup header="All recurring">
            {L.rules.map((r) => {
              const cat = r.categoryId ? L.categoryById.get(r.categoryId) : undefined
              const next = nextDueDate(r)
              return (
                <ListRow
                  key={r.id}
                  onClick={() => open(r)}
                  className={r.active ? '' : 'opacity-50'}
                  leading={<IconBadge icon={cat?.icon ?? (r.type === 'transfer' ? '🔄' : '🔁')} color={cat?.color ?? 'gray'} />}
                  title={r.note || cat?.name || 'Transfer'}
                  subtitle={`${describeSchedule(r)}${r.active ? (next ? ` · next ${formatDayPhrase(next, today)}` : ' · ended') : ' · paused'}`}
                  value={
                    <span className={r.type === 'income' ? 'text-positive tabular' : 'tabular'}>
                      {r.type === 'income' ? '+' : ''}
                      {formatNumber(r.amount)}
                    </span>
                  }
                />
              )
            })}
          </ListGroup>
        </>
      )}
      <RecurringSheet key={sheet.key} open={sheet.open} rule={sheet.rule} onClose={() => setSheet((s) => ({ ...s, open: false }))} />
    </Page>
  )
}
