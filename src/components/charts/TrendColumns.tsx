import { useState } from 'react'
import type { TrendPoint } from '@/domain/insights'
import { useWidth } from '@/hooks/useWidth'
import { formatMonthShort, type MonthKey } from '@/lib/dates'
import { formatCompact, formatRp } from '@/lib/money'
import { niceMax } from './ChartCard'

const H = 168
const PAD = { top: 12, right: 4, bottom: 24, left: 40 }
const BAR_MAX = 18
const GAP = 2

/** Grouped columns: income vs spending per month. One axis, clean ticks, tap for details. */
export function TrendColumns({ data, selected }: { data: TrendPoint[]; selected: MonthKey }) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [active, setActive] = useState<number | null>(null)

  const max = niceMax(Math.max(1, ...data.flatMap((d) => [d.income, d.expense])))
  const plotW = width - PAD.left - PAD.right
  const plotH = H - PAD.top - PAD.bottom
  const band = plotW / data.length
  const bar = Math.min(BAR_MAX, (band - 12) / 2 - GAP)
  const y = (v: number) => PAD.top + plotH - (v / max) * plotH
  const ticks = [0, max / 2, max]

  /** Column with a 4px rounded data-end, square at the baseline. */
  const col = (x: number, v: number) => {
    const top = y(v)
    const h = Math.max(0, PAD.top + plotH - top)
    if (h <= 0) return ''
    const r = Math.min(4, h, bar / 2)
    const base = PAD.top + plotH
    return `M${x},${base} V${top + r} Q${x},${top} ${x + r},${top} H${x + bar - r} Q${x + bar},${top} ${x + bar},${top + r} V${base} Z`
  }

  const a = active != null ? data[active] : null

  return (
    <div ref={ref} className="relative select-none" onPointerLeave={() => setActive(null)}>
      <svg width={width} height={H} role="img" aria-label="Income and spending over the last six months">
        {ticks.map((t) => (
          <g key={t}>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(t)} y2={y(t)} stroke="var(--viz-grid)" strokeWidth={1} />
            <text x={PAD.left - 6} y={y(t)} dy="0.32em" textAnchor="end" className="fill-label-2 tabular text-[10px]">
              {formatCompact(t)}
            </text>
          </g>
        ))}
        {data.map((d, i) => {
          const cx = PAD.left + band * i + band / 2
          const isSel = d.month === selected
          return (
            <g key={d.month} opacity={active != null && active !== i ? 0.45 : 1}>
              <path d={col(cx - bar - GAP / 2, d.income)} fill="var(--viz-income)" />
              <path d={col(cx + GAP / 2, d.expense)} fill="var(--viz-expense)" />
              <text
                x={cx}
                y={H - 6}
                textAnchor="middle"
                className={isSel ? 'fill-label text-[11px] font-semibold' : 'fill-label-2 text-[11px]'}
              >
                {formatMonthShort(d.month)}
              </text>
              {/* generous hit target: the whole band */}
              <rect
                x={PAD.left + band * i}
                y={PAD.top}
                width={band}
                height={plotH + PAD.bottom}
                fill="transparent"
                onPointerEnter={() => setActive(i)}
                onPointerDown={() => setActive(i)}
              />
            </g>
          )
        })}
      </svg>
      {a && active != null && (
        <div
          role="status"
          className="bg-elevated pointer-events-none absolute top-0 z-10 w-max rounded-[10px] px-3 py-2 text-[12px] shadow-[0_6px_24px_rgb(0_0_0/0.16)]"
          style={{
            left: Math.min(Math.max(PAD.left + band * active + band / 2 - 70, 0), width - 150),
          }}
        >
          <div className="mb-1 font-semibold">{formatMonthShort(a.month)} {a.month.slice(0, 4)}</div>
          <Row color="var(--viz-income)" label="Income" value={formatRp(a.income)} />
          <Row color="var(--viz-expense)" label="Spending" value={formatRp(a.expense)} />
          <div className="text-label-2 hairline-t mt-1 pt-1">Net {formatRp(a.income - a.expense)}</div>
        </div>
      )}
    </div>
  )
}

function Row({ color, label, value }: { color: string; label: string; value: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className="size-2 rounded-[2px]" style={{ background: color }} aria-hidden />
      <span className="text-label-2">{label}</span>
      <span className="tabular ml-auto pl-3 font-medium">{value}</span>
    </div>
  )
}
