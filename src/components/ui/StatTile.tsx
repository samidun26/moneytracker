import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'
import { formatRp, formatRpCompact } from '@/lib/money'

/** Full rupiah when it fits the tile, compact (jt/M) when it doesn't — never truncated. */
export function fitRp(n: number, signed = false): { text: string; size: string } {
  const sign = signed && n > 0 ? '+' : ''
  const full = sign + formatRp(n)
  if (full.length <= 10) return { text: full, size: 'text-[22px]' }
  if (full.length <= 12) return { text: full, size: 'text-[19px]' }
  return { text: sign + formatRpCompact(n), size: 'text-[22px]' }
}

/** KPI stat tile: label · value · optional delta line. */
export function StatTile({
  label,
  value,
  delta,
  deltaTone = 'neutral',
  icon,
  className,
  money,
  signed,
  valueClassName,
}: {
  label: string
  value?: ReactNode
  /** Pass an amount instead of `value` to get automatic fitting */
  money?: number
  signed?: boolean
  valueClassName?: string
  delta?: ReactNode
  deltaTone?: 'positive' | 'negative' | 'neutral'
  icon?: ReactNode
  className?: string
}) {
  return (
    <div className={cn('bg-surface rounded-[var(--radius-card)] p-3.5', className)}>
      <div className="text-label-2 flex items-center gap-1.5 text-[13px] font-medium">
        {icon}
        {label}
      </div>
      {money != null ? (
        <div className={cn('mt-1 truncate leading-7 font-semibold tracking-tight', fitRp(money, signed).size, valueClassName)}>
          {fitRp(money, signed).text}
        </div>
      ) : (
        <div className={cn('mt-1 truncate text-[22px] leading-7 font-semibold tracking-tight', valueClassName)}>{value}</div>
      )}
      {delta && (
        <div
          className={cn(
            'mt-0.5 truncate text-[13px]',
            deltaTone === 'positive' && 'text-positive',
            deltaTone === 'negative' && 'text-negative',
            deltaTone === 'neutral' && 'text-label-2',
          )}
        >
          {delta}
        </div>
      )}
    </div>
  )
}
