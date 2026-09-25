import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { ChevronRight, Plus, Target } from 'lucide-react'
import { monthSummary, netWorth } from '@/domain/balances'
import { budgetProgress, expectedPace, spendingByCategory } from '@/domain/budgets'
import { monthToDateExpense } from '@/domain/insights'
import { upcomingOccurrences } from '@/domain/recurring'
import { useLedger } from '@/hooks/useLedger'
import { useToday } from '@/hooks/useToday'
import { formatMonth, monthKey, shiftMonth } from '@/lib/dates'
import { formatRp, formatRpCompact } from '@/lib/money'
import { cn } from '@/lib/cn'
import { Page } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { StatTile } from '@/components/ui/StatTile'
import { Meter } from '@/components/ui/Meter'
import { EmptyState } from '@/components/ui/EmptyState'
import { Button } from '@/components/ui/Button'
import { GlyphBadge } from '@/components/ui/IconBadge'
import { SyncIndicator } from '@/components/SyncIndicator'
import { InstallBanner } from '@/components/InstallBanner'
import { useComposer } from '@/features/transactions/Composer'
import { TransactionRow } from '@/features/transactions/TransactionRow'
import { BudgetRow, BudgetStatusText } from '@/features/budgets/BudgetRow'
import { OccurrenceRow } from '@/features/recurring/OccurrenceRow'

export function HomePage() {
  const L = useLedger()
  const today = useToday()
  const compose = useComposer()
  const month = monthKey(today)
  const day = Number(today.slice(8))

  const summary = useMemo(() => monthSummary(L.transactions, month), [L.transactions, month])
  const worth = netWorth(L.accounts, L.balances)
  const lastMtd = useMemo(() => monthToDateExpense(L.transactions, shiftMonth(month, -1), day), [L.transactions, month, day])
  const spentDelta = lastMtd > 0 ? (summary.expense - lastMtd) / lastMtd : null

  const spending = useMemo(() => spendingByCategory(L.transactions, month), [L.transactions, month])
  const pace = expectedPace(month, today)
  const overall = L.budgets.find((b) => b.categoryId === null)
  const overallP = overall ? budgetProgress(overall, spending.get(null) ?? 0, month, today) : null
  const catBudgets = L.budgets
    .filter((b) => b.categoryId && L.categoryById.has(b.categoryId))
    .map((b) => budgetProgress(b, spending.get(b.categoryId) ?? 0, month, today))
    .sort((a, b) => b.ratio - a.ratio)
    .slice(0, 3)

  const upcoming = useMemo(() => upcomingOccurrences(L.rules, today, 7).slice(0, 5), [L.rules, today])
  const recent = L.transactions.slice(0, 5)

  return (
    <Page title="Overview" actions={<SyncIndicator />}>
      <InstallBanner />

      {/* Net worth */}
      <Link to="/accounts" className="bg-surface press mx-4 mb-4 block rounded-[var(--radius-card)] p-4">
        <div className="text-label-2 flex items-center justify-between text-[13px] font-medium">
          <span>Net worth</span>
          <ChevronRight className="text-label-3 size-4" strokeWidth={2.6} />
        </div>
        <div className={cn('mt-0.5 text-[34px] leading-[40px] font-bold tracking-tight', worth < 0 && 'text-negative')}>
          {formatRp(worth)}
        </div>
        {L.activeAccounts.length > 0 && (
          <div className="no-scrollbar -mx-4 mt-3 flex gap-2 overflow-x-auto px-4">
            {L.activeAccounts.map((a) => {
              const bal = L.balances.get(a.id) ?? 0
              return (
                <span key={a.id} className="bg-fill flex shrink-0 items-center gap-1.5 rounded-full py-1 pr-3 pl-2 text-[13px]">
                  <span aria-hidden>{a.icon}</span>
                  <span className="text-label-2">{a.name}</span>
                  <span className={cn('font-semibold', bal < 0 && 'text-negative')}>{formatRpCompact(bal)}</span>
                </span>
              )
            })}
          </div>
        )}
      </Link>

      {/* This month */}
      <div className="mx-4 mb-8 grid grid-cols-2 gap-3">
        <StatTile
          label={`Spent in ${formatMonth(month).split(' ')[0]}`}
          money={summary.expense}
          delta={
            spentDelta == null
              ? `${summary.count} transactions`
              : `${spentDelta > 0 ? '▲' : '▼'} ${Math.abs(Math.round(spentDelta * 100))}% vs last month`
          }
          deltaTone={spentDelta == null ? 'neutral' : spentDelta > 0.05 ? 'negative' : spentDelta < -0.05 ? 'positive' : 'neutral'}
        />
        <StatTile
          label="Income"
          money={summary.income}
          valueClassName={summary.income > 0 ? 'text-positive' : undefined}
          delta={summary.income > 0 ? `Net ${summary.net >= 0 ? '+' : ''}${formatRpCompact(summary.net)}` : 'Nothing yet this month'}
          deltaTone={summary.income === 0 ? 'neutral' : summary.net >= 0 ? 'positive' : 'negative'}
        />
      </div>

      {/* Budgets */}
      {overallP || catBudgets.length ? (
        <ListGroup header="Budget" action={<Link to="/budgets" className="text-tint">See all</Link>}>
          {overallP && (
            <Link to="/budgets" className="group row-press block px-4 py-3.5">
              <div className="flex items-baseline justify-between">
                <span className="text-[16px] font-semibold">{formatRp(overallP.spent)}</span>
                <span className="text-label-2 text-[13px]">of {formatRp(overallP.limit)}</span>
              </div>
              <Meter ratio={overallP.ratio} status={overallP.status} pace={pace} thick className="my-2" />
              <div className="flex justify-between text-[13px]">
                <BudgetStatusText p={overallP} />
                {overallP.perDayLeft != null && overallP.remaining > 0 && (
                  <span className="text-label-2">
                    {formatRpCompact(overallP.perDayLeft)}/day · {overallP.daysLeft}d left
                  </span>
                )}
              </div>
            </Link>
          )}
          {catBudgets.map((p) => (
            <BudgetRow key={p.budget.id} p={p} category={L.categoryById.get(p.budget.categoryId!)} pace={pace} />
          ))}
        </ListGroup>
      ) : (
        L.transactions.length > 0 && (
          <ListGroup>
            <ListRow
              to="/budgets"
              leading={
                <GlyphBadge color="orange">
                  <Target className="size-[18px]" />
                </GlyphBadge>
              }
              title="Set a monthly budget"
              subtitle="Know how much is left to spend each day"
            />
          </ListGroup>
        )
      )}

      {/* Upcoming bills */}
      {upcoming.length > 0 && (
        <ListGroup header="Upcoming · next 7 days" action={<Link to="/recurring" className="text-tint">All</Link>}>
          {upcoming.map((o) => (
            <OccurrenceRow key={`${o.rule.id}-${o.date}`} o={o} />
          ))}
        </ListGroup>
      )}

      {/* Recent */}
      {recent.length ? (
        <ListGroup header="Recent" action={<Link to="/activity" className="text-tint">See all</Link>}>
          {recent.map((t) => (
            <TransactionRow key={t.id} tx={t} />
          ))}
        </ListGroup>
      ) : (
        L.ready && (
          <EmptyState
            icon="🧾"
            title="No transactions yet"
            body="Log your first expense. It takes about three seconds, and it works offline."
            action={
              <Button size="md" onClick={() => compose()}>
                <Plus className="size-4" strokeWidth={3} /> Add expense
              </Button>
            }
          />
        )
      )}
    </Page>
  )
}
