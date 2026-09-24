import { useMemo, useState } from 'react'
import { Plus } from 'lucide-react'
import type { Budget } from '@/db/types'
import { budgetProgress, expectedPace, spendingByCategory } from '@/domain/budgets'
import { useLedger } from '@/hooks/useLedger'
import { useToday } from '@/hooks/useToday'
import { monthKey, shiftMonth } from '@/lib/dates'
import { formatRp, formatRpCompact } from '@/lib/money'
import { Page, NavButton } from '@/components/ui/Page'
import { MonthSwitcher } from '@/components/ui/MonthSwitcher'
import { ListGroup, ListRow } from '@/components/ui/List'
import { Meter } from '@/components/ui/Meter'
import { EmptyState } from '@/components/ui/EmptyState'
import { Button } from '@/components/ui/Button'
import { IconBadge } from '@/components/ui/IconBadge'
import { BudgetRow, BudgetStatusText } from '@/features/budgets/BudgetRow'
import { BudgetSheet } from '@/features/budgets/BudgetSheet'

export function BudgetsPage() {
  const L = useLedger()
  const today = useToday()
  const [month, setMonth] = useState(monthKey(today))
  const [sheet, setSheet] = useState<{ open: boolean; budget?: Budget; categoryId?: string | null; key: number }>({ open: false, key: 0 })
  const openSheet = (budget?: Budget, categoryId?: string | null) => setSheet((s) => ({ open: true, budget, categoryId, key: s.key + 1 }))

  const spending = useMemo(() => spendingByCategory(L.transactions, month), [L.transactions, month])
  const pace = expectedPace(month, today)

  /** Average of the previous 3 months — used to suggest a sensible limit. */
  const suggested = useMemo(() => {
    const months = [1, 2, 3].map((i) => spendingByCategory(L.transactions, shiftMonth(monthKey(today), -i)))
    return (categoryId: string | null) => Math.round(months.reduce((s, m) => s + (m.get(categoryId) ?? 0), 0) / 3)
  }, [L.transactions, today])

  const overall = L.budgets.find((b) => b.categoryId === null)
  const overallP = overall ? budgetProgress(overall, spending.get(null) ?? 0, month, today) : null
  const rows = L.budgets
    .filter((b) => b.categoryId)
    .map((b) => budgetProgress(b, spending.get(b.categoryId) ?? 0, month, today))
    .sort((a, b) => b.ratio - a.ratio)
  const budgeted = new Set(L.budgets.map((b) => b.categoryId))
  const unbudgeted = L.categories
    .filter((c) => c.kind === 'expense' && !budgeted.has(c.id))
    .map((c) => ({ c, spent: spending.get(c.id) ?? 0 }))
    .sort((a, b) => b.spent - a.spent)
  const totalLimits = rows.reduce((s, r) => s + r.limit, 0)

  return (
    <Page
      title="Budgets"
      back={{ label: 'More', to: '/more' }}
      actions={
        <NavButton label="Add budget" onClick={() => openSheet()}>
          <Plus className="size-6" strokeWidth={2.4} />
        </NavButton>
      }
      subheader={<MonthSwitcher month={month} onChange={setMonth} />}
    >
      {!overallP && rows.length === 0 ? (
        <EmptyState
          icon="🎯"
          title="No budgets yet"
          body="Set a monthly limit for everything, or for the categories you want to watch, like food or shopping."
          action={<Button size="md" onClick={() => openSheet(undefined, null)}>Set overall budget</Button>}
        />
      ) : (
        <>
          {overallP ? (
            <button type="button" onClick={() => openSheet(overall)} className="bg-surface press mx-4 mb-8 block w-[calc(100%-2rem)] rounded-[var(--radius-card)] p-4 text-left">
              <div className="text-label-2 text-[13px] font-medium">Overall budget</div>
              <div className="mt-0.5 flex items-baseline justify-between gap-2">
                <span className="text-[28px] font-bold tracking-tight">{formatRp(overallP.spent)}</span>
                <span className="text-label-2 text-[15px]">of {formatRpCompact(overallP.limit)}</span>
              </div>
              <Meter ratio={overallP.ratio} status={overallP.status} pace={pace} thick className="my-2.5" />
              <div className="flex justify-between gap-2 text-[13px]">
                <BudgetStatusText p={overallP} />
                {overallP.perDayLeft != null && overallP.remaining > 0 && (
                  <span className="text-label-2">
                    {formatRpCompact(overallP.perDayLeft)}/day for {overallP.daysLeft} days
                  </span>
                )}
              </div>
              {pace != null && <p className="text-label-3 mt-2 text-[12px]">The tick marks where you’d be at an even pace today.</p>}
            </button>
          ) : (
            <ListGroup>
              <ListRow tinted title="Set an overall monthly budget" onClick={() => openSheet(undefined, null)} chevron={false} />
            </ListGroup>
          )}

          {rows.length > 0 && (
            <ListGroup
              header="By category"
              footer={overallP && totalLimits > overallP.limit ? `Category limits add up to ${formatRp(totalLimits)}, more than your overall budget.` : undefined}
            >
              {rows.map((p) => (
                <BudgetRow key={p.budget.id} p={p} category={L.categoryById.get(p.budget.categoryId!)} pace={pace} onClick={() => openSheet(p.budget)} />
              ))}
            </ListGroup>
          )}
        </>
      )}

      {unbudgeted.length > 0 && (overallP || rows.length > 0) && (
        <ListGroup header="Add a category budget">
          {unbudgeted.slice(0, 8).map(({ c, spent }) => (
            <ListRow
              key={c.id}
              leading={<IconBadge icon={c.icon} color={c.color} />}
              title={c.name}
              subtitle={spent > 0 ? `${formatRp(spent)} spent this month` : undefined}
              trailing={<Plus className="text-tint size-5" strokeWidth={2.4} />}
              onClick={() => openSheet(undefined, c.id)}
            />
          ))}
        </ListGroup>
      )}

      <BudgetSheet
        key={sheet.key}
        open={sheet.open}
        onClose={() => setSheet((s) => ({ ...s, open: false }))}
        budget={sheet.budget}
        initialCategoryId={sheet.categoryId}
        suggested={suggested}
      />
    </Page>
  )
}
