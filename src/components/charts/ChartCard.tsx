import { useState, type ReactNode } from 'react'
import { cn } from '@/lib/cn'

/** Card wrapper with title, legend slot and a Chart/Table toggle (the table is the accessible twin). */
export function ChartCard({
  title,
  subtitle,
  legend,
  chart,
  table,
  className,
}: {
  title: string
  subtitle?: ReactNode
  legend?: ReactNode
  chart: ReactNode
  table?: ReactNode
  className?: string
}) {
  const [view, setView] = useState<'chart' | 'table'>('chart')
  return (
    <section className={cn('bg-surface mx-4 mb-8 rounded-[var(--radius-card)] p-4', className)}>
      <div className="mb-3 flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h3 className="text-[17px] font-semibold">{title}</h3>
          {subtitle && <p className="text-label-2 mt-0.5 text-[13px]">{subtitle}</p>}
        </div>
        {table && (
          <div className="bg-fill flex shrink-0 rounded-[8px] p-0.5 text-[12px] font-medium" role="tablist" aria-label="View">
            {(['chart', 'table'] as const).map((v) => (
              <button
                key={v}
                type="button"
                role="tab"
                aria-selected={view === v}
                onClick={() => setView(v)}
                className={cn('rounded-[6px] px-2 py-1 capitalize', view === v ? 'bg-elevated shadow-sm' : 'text-label-2')}
              >
                {v}
              </button>
            ))}
          </div>
        )}
      </div>
      {legend && view === 'chart' && <div className="text-label-2 mb-2 flex flex-wrap gap-x-4 gap-y-1 text-[12px]">{legend}</div>}
      {view === 'chart' || !table ? chart : table}
    </section>
  )
}

export function LegendItem({ color, label, line }: { color: string; label: string; line?: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span
        aria-hidden
        className={line ? 'h-[2px] w-3.5 rounded-full' : 'size-2.5 rounded-[3px]'}
        style={{ background: color }}
      />
      {label}
    </span>
  )
}

export function DataTable({ head, rows }: { head: string[]; rows: Array<Array<ReactNode>> }) {
  return (
    <div className="-mx-1 overflow-x-auto">
      <table className="tabular w-full text-[13px]">
        <thead>
          <tr className="text-label-2 text-left">
            {head.map((h, i) => (
              <th key={h} className={cn('px-1 pb-1.5 font-medium', i > 0 && 'text-right')}>
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} className="hairline-t">
              {r.map((c, j) => (
                <td key={j} className={cn('px-1 py-1.5', j > 0 && 'text-right')}>
                  {c}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

/** Round an axis max up to a clean number (1, 2, 2.5, 5 × 10ⁿ). */
export function niceMax(v: number): number {
  if (v <= 0) return 1
  const exp = Math.pow(10, Math.floor(Math.log10(v)))
  const f = v / exp
  const steps = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]
  return (steps.find((s) => f <= s) ?? 10) * exp
}
