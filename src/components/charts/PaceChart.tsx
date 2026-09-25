import { useState } from 'react'
import { useWidth } from '@/hooks/useWidth'
import { formatCompact, formatRp } from '@/lib/money'
import { niceMax } from './ChartCard'

const H = 180
const PAD = { top: 16, right: 12, bottom: 22, left: 40 }

/**
 * Cumulative spending this month (accent) vs last month (de-emphasis gray),
 * with an optional budget reference line. Emphasis form: one story, one color.
 */
export function PaceChart({
  current,
  previous,
  budget,
  todayIndex,
}: {
  current: number[]
  previous: number[]
  budget?: number | null
  /** 0-based day index of "today" if this is the current month, else last day */
  todayIndex: number
}) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const [active, setActive] = useState<number | null>(null)

  const days = Math.max(current.length, previous.length)
  const shown = current.slice(0, todayIndex + 1)
  const max = niceMax(Math.max(1, ...shown, ...previous, budget ?? 0) * 1.05)
  const plotW = width - PAD.left - PAD.right
  const plotH = H - PAD.top - PAD.bottom
  const x = (i: number) => PAD.left + (days <= 1 ? 0 : (i / (days - 1)) * plotW)
  const y = (v: number) => PAD.top + plotH - (v / max) * plotH
  const line = (vals: number[]) => vals.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ')
  const ticks = [0, max / 2, max]
  const last = shown.length - 1

  const onMove = (e: React.PointerEvent<SVGRectElement>) => {
    const r = e.currentTarget.getBoundingClientRect()
    const i = Math.round(((e.clientX - r.left) / r.width) * (days - 1))
    setActive(Math.max(0, Math.min(days - 1, i)))
  }

  return (
    <div ref={ref} className="relative select-none" onPointerLeave={() => setActive(null)}>
      <svg width={width} height={H} role="img" aria-label="Cumulative spending this month compared with last month">
        {ticks.map((t) => (
          <g key={t}>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(t)} y2={y(t)} stroke="var(--viz-grid)" strokeWidth={1} />
            <text x={PAD.left - 6} y={y(t)} dy="0.32em" textAnchor="end" className="fill-label-2 tabular text-[10px]">
              {formatCompact(t)}
            </text>
          </g>
        ))}
        {[1, 8, 15, 22, days].map((d) => (
          <text key={d} x={x(d - 1)} y={H - 6} textAnchor="middle" className="fill-label-2 tabular text-[10px]">
            {d}
          </text>
        ))}
        {budget ? (
          <g>
            <line x1={PAD.left} x2={width - PAD.right} y1={y(budget)} y2={y(budget)} stroke="var(--c-label-3)" strokeWidth={1} />
            <text x={width - PAD.right} y={y(budget) - 5} textAnchor="end" className="fill-label-2 text-[10px] font-medium">
              Budget {formatCompact(budget)}
            </text>
          </g>
        ) : null}
        <path d={line(previous)} fill="none" stroke="var(--viz-muted)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
        {shown.length > 0 && (
          <>
            <path
              d={`${line(shown)} L${x(last)},${y(0)} L${x(0)},${y(0)} Z`}
              fill="var(--viz-expense)"
              opacity={0.1}
            />
            <path d={line(shown)} fill="none" stroke="var(--viz-expense)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
            <circle cx={x(last)} cy={y(shown[last])} r={4} fill="var(--viz-expense)" stroke="var(--c-surface)" strokeWidth={2} />
          </>
        )}
        {active != null && (
          <line x1={x(active)} x2={x(active)} y1={PAD.top} y2={PAD.top + plotH} stroke="var(--c-label-3)" strokeWidth={1} />
        )}
        <rect
          x={PAD.left}
          y={0}
          width={plotW}
          height={H}
          fill="transparent"
          onPointerMove={onMove}
          onPointerDown={onMove}
          style={{ touchAction: 'pan-y' }}
        />
      </svg>
      {active != null && (
        <div
          role="status"
          className="bg-elevated pointer-events-none absolute top-0 z-10 w-max rounded-[10px] px-3 py-2 text-[12px] shadow-[0_6px_24px_rgb(0_0_0/0.16)]"
          style={{ left: Math.min(Math.max(x(active) - 75, 0), width - 160) }}
        >
          <div className="mb-1 font-semibold">Day {active + 1}</div>
          {active <= last && (
            <div className="flex items-center gap-1.5">
              <span className="h-[2px] w-3 rounded-full" style={{ background: 'var(--viz-expense)' }} aria-hidden />
              <span className="text-label-2">This month</span>
              <span className="tabular ml-auto pl-3 font-medium">{formatRp(shown[active])}</span>
            </div>
          )}
          {active < previous.length && (
            <div className="flex items-center gap-1.5">
              <span className="h-[2px] w-3 rounded-full" style={{ background: 'var(--viz-muted)' }} aria-hidden />
              <span className="text-label-2">Last month</span>
              <span className="tabular ml-auto pl-3 font-medium">{formatRp(previous[active])}</span>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
