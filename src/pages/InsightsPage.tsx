import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { monthSummary } from '@/domain/balances'
import { categoryBreakdown, cumulativeDaily, dailyAverage, largestExpense, monthlyTrend } from '@/domain/insights'
import { useLedger } from '@/hooks/useLedger'
import { useToday } from '@/hooks/useToday'
import { formatDayLabel, formatMonth, formatMonthShort, monthBounds, monthKey, shiftMonth } from '@/lib/dates'
import { formatRp, formatRpCompact } from '@/lib/money'
import { Page } from '@/components/ui/Page'
import { MonthSwitcher } from '@/components/ui/MonthSwitcher'
import { StatTile } from '@/components/ui/StatTile'
import { EmptyState } from '@/components/ui/EmptyState'
import { ListGroup, ListRow } from '@/components/ui/List'
import { ChartCard, DataTable, LegendItem } from '@/components/charts/ChartCard'
import { CategoryBars } from '@/components/charts/CategoryBars'
import { PaceChart } from '@/components/charts/PaceChart'
import { TrendColumns } from '@/components/charts/TrendColumns'
import { useComposer } from '@/features/transactions/Composer'

export function InsightsPage() {
  const L = useLedger()
  const today = useToday()
  const compose = useComposer()
  const navigate = useNavigate()
  const [month, setMonth] = useState(monthKey(today))
  const isCurrent = month === monthKey(today)

  const s = useMemo(() => monthSummary(L.transactions, month), [L.transactions, month])
  const prev = useMemo(() => monthSummary(L.transactions, shiftMonth(month, -1)), [L.transactions, month])
  const slices = useMemo(() => categoryBreakdown(L.transactions, month), [L.transactions, month])
  const trend = useMemo(() => monthlyTrend(L.transactions, month, 6), [L.transactions, month])
  const cur = useMemo(() => cumulativeDaily(L.transactions, month), [L.transactions, month])
  const last = useMemo(() => cumulativeDaily(L.transactions, shiftMonth(month, -1)), [L.transactions, month])
  const biggest = useMemo(() => largestExpense(L.transactions, month), [L.transactions, month])
  const overall = L.budgets.find((b) => b.categoryId === null)

  const savingsRate = s.income > 0 ? s.net / s.income : null
  const avg = dailyAverage(s.expense, month, today)
  const todayIndex = isCurrent ? Number(today.slice(8)) - 1 : monthBounds(month).days - 1
  const delta = (a: number, b: number) => (b > 0 ? (a - b) / b : null)
  const pct = (v: number | null) => (v == null ? undefined : `${v > 0 ? '▲' : '▼'} ${Math.abs(Math.round(v * 100))}% vs ${formatMonthShort(shiftMonth(month, -1))}`)
  const spentDelta = isCurrent ? null : delta(s.expense, prev.expense)
  const incomeDelta = isCurrent ? null : delta(s.income, prev.income)

  return (
    <Page title="Insights" subheader={<MonthSwitcher month={month} onChange={setMonth} />}>
      <div className="mx-4 mb-8 grid grid-cols-2 gap-3">
        <StatTile
          label="Spent"
          money={s.expense}
          delta={pct(spentDelta) ?? `${formatRpCompact(avg)} per day`}
          deltaTone={spentDelta == null ? 'neutral' : spentDelta > 0 ? 'negative' : 'positive'}
        />
        <StatTile
          label="Income"
          money={s.income}
          delta={pct(incomeDelta) ?? `${s.count} transactions`}
          deltaTone={incomeDelta == null ? 'neutral' : incomeDelta >= 0 ? 'positive' : 'negative'}
        />
        <StatTile
          label="Net"
          money={s.net}
          signed
          valueClassName={s.net < 0 ? 'text-negative' : s.net > 0 ? 'text-positive' : ''}
          delta={s.net >= 0 ? 'Saved this month' : 'More out than in'}
        />
        <StatTile
          label="Savings rate"
          value={savingsRate == null ? '—' : savingsRate < -1 ? '< −100%' : `${savingsRate < 0 ? '−' : ''}${Math.abs(Math.round(savingsRate * 100))}%`}
          delta={savingsRate == null ? 'No income logged' : savingsRate >= 0.2 ? 'Healthy (≥ 20%)' : savingsRate >= 0 ? 'Aim for 20%' : isCurrent ? 'Income may still arrive' : 'Spent more than earned'}
          deltaTone={savingsRate == null ? 'neutral' : savingsRate >= 0.2 ? 'positive' : savingsRate < 0 ? 'negative' : 'neutral'}
        />
      </div>

      {slices.length === 0 ? (
        L.ready && (
          <EmptyState
            icon="📊"
            title={`No spending in ${formatMonth(month)}`}
            body="Insights appear as soon as you log expenses."
            action={
              <button type="button" onClick={() => compose()} className="text-tint text-[17px] font-medium">
                Add an expense
              </button>
            }
          />
        )
      ) : (
        <>
          <ChartCard
            title="Where it went"
            subtitle={`${formatRp(s.expense)} across ${slices.length} ${slices.length === 1 ? 'category' : 'categories'}`}
            chart={
              <CategoryBars
                slices={slices}
                categoryById={L.categoryById}
                onSelect={() => navigate('/activity')}
              />
            }
          />

          <ChartCard
            title="Spending pace"
            subtitle={
              isCurrent
                ? cur[todayIndex] > (last[todayIndex] ?? 0)
                  ? `${formatRpCompact(cur[todayIndex] - (last[todayIndex] ?? 0))} more than ${formatMonthShort(shiftMonth(month, -1))} by day ${todayIndex + 1}`
                  : `${formatRpCompact((last[todayIndex] ?? 0) - cur[todayIndex])} less than ${formatMonthShort(shiftMonth(month, -1))} by day ${todayIndex + 1}`
                : 'Cumulative spending, day by day'
            }
            legend={
              <>
                <LegendItem line color="var(--viz-expense)" label={formatMonthShort(month)} />
                <LegendItem line color="var(--viz-muted)" label={formatMonthShort(shiftMonth(month, -1))} />
              </>
            }
            chart={<PaceChart current={cur} previous={last} budget={overall?.amount} todayIndex={todayIndex} />}
            table={
              <DataTable
                head={['Day', formatMonthShort(month), formatMonthShort(shiftMonth(month, -1))]}
                rows={[7, 14, 21, cur.length]
                  .filter((d, i, a) => a.indexOf(d) === i)
                  .map((d) => [d, d - 1 <= todayIndex ? formatRp(cur[d - 1] ?? 0) : '—', formatRp(last[Math.min(d, last.length) - 1] ?? 0)])}
              />
            }
          />
        </>
      )}

      {trend.some((t) => t.income || t.expense) && (
        <ChartCard
          title="Income vs spending"
          subtitle="Last 6 months"
          legend={
            <>
              <LegendItem color="var(--viz-income)" label="Income" />
              <LegendItem color="var(--viz-expense)" label="Spending" />
            </>
          }
          chart={<TrendColumns data={trend} selected={month} />}
          table={
            <DataTable
              head={['Month', 'Income', 'Spending', 'Net']}
              rows={trend.map((t) => [
                `${formatMonthShort(t.month)} ${t.month.slice(2, 4)}`,
                formatRpCompact(t.income),
                formatRpCompact(t.expense),
                formatRpCompact(t.income - t.expense),
              ])}
            />
          }
        />
      )}

      {biggest && (
        <ListGroup header="Highlights">
          <ListRow title="Daily average" value={formatRp(avg)} />
          <ListRow
            title="Biggest expense"
            subtitle={`${biggest.note || L.categoryById.get(biggest.categoryId ?? '')?.name || ''} · ${formatDayLabel(biggest.date, today)}`}
            value={formatRp(biggest.amount)}
            onClick={() => compose({ tx: biggest })}
          />
          <ListRow title="Transactions" value={String(s.count)} />
        </ListGroup>
      )}
    </Page>
  )
}
