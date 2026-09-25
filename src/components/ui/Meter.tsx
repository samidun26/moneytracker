import type { BudgetStatus } from '@/domain/budgets'
import { cn } from '@/lib/cn'

const FILL: Record<BudgetStatus, string> = {
  ok: 'var(--c-tint)',
  warn: 'var(--c-warning-fill)',
  over: 'var(--c-negative-fill)',
}

/**
 * Budget meter: the fill carries severity; the track is a light step of the
 * same hue so state reads across the whole bar. Optional pace marker shows
 * where spending "should" be today.
 */
export function Meter({
  ratio,
  status,
  pace,
  className,
  thick,
}: {
  ratio: number
  status: BudgetStatus
  pace?: number | null
  className?: string
  thick?: boolean
}) {
  const fill = FILL[status]
  const pct = Math.min(1, Math.max(0, ratio)) * 100
  return (
    <div
      className={cn('relative w-full overflow-hidden rounded-full', thick ? 'h-2.5' : 'h-1.5', className)}
      style={{ background: `color-mix(in srgb, ${fill} 16%, transparent)` }}
    >
      <div
        className="h-full rounded-full transition-[width] duration-500 ease-[var(--ease-ios)]"
        style={{ width: `${pct}%`, background: fill, minWidth: ratio > 0 ? 6 : 0 }}
      />
      {pace != null && pace > 0 && pace < 1 && (
        <span
          aria-hidden
          className="bg-label/50 absolute top-0 bottom-0 w-[2px] rounded-full"
          style={{ left: `calc(${pace * 100}% - 1px)` }}
        />
      )}
    </div>
  )
}
