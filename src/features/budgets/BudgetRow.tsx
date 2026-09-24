import { CircleAlert, TriangleAlert } from 'lucide-react'
import type { BudgetProgress } from '@/domain/budgets'
import type { Category } from '@/db/types'
import { cn } from '@/lib/cn'
import { formatRp, formatRpCompact } from '@/lib/money'
import { IconBadge } from '@/components/ui/IconBadge'
import { Meter } from '@/components/ui/Meter'

/** Status always carries an icon + words, never color alone. */
export function BudgetStatusText({ p, compact }: { p: BudgetProgress; compact?: boolean }) {
  const fmt = compact ? formatRpCompact : formatRp
  if (p.status === 'over')
    return (
      <span className="text-negative inline-flex items-center gap-1">
        <CircleAlert className="size-3.5" aria-hidden /> Over by {fmt(-p.remaining)}
      </span>
    )
  if (p.status === 'warn')
    return (
      <span className="text-warning inline-flex items-center gap-1">
        <TriangleAlert className="size-3.5" aria-hidden /> {fmt(p.remaining)} left
      </span>
    )
  return <span className="text-label-2">{fmt(p.remaining)} left</span>
}

export function BudgetRow({
  p,
  category,
  pace,
  onClick,
}: {
  p: BudgetProgress
  category?: Category
  pace?: number | null
  onClick?: () => void
}) {
  const Tag = onClick ? 'button' : 'div'
  return (
    <Tag type={onClick ? 'button' : undefined} onClick={onClick} className={cn('group flex w-full items-center gap-3 pl-4 text-left', onClick && 'row-press')}>
      <IconBadge icon={category?.icon ?? '❔'} color={category?.color ?? 'gray'} />
      <div className="row-sep min-w-0 flex-1 py-3 pr-4">
        <div className="flex items-baseline justify-between gap-2">
          <span className="truncate text-[16px] font-medium">{category?.name ?? 'Deleted category'}</span>
          <span className="text-label-2 tabular shrink-0 text-[13px]">
            {formatRpCompact(p.spent)} / {formatRpCompact(p.limit)}
          </span>
        </div>
        <Meter ratio={p.ratio} status={p.status} pace={pace} className="my-1.5" />
        <div className="text-[13px]">
          <BudgetStatusText p={p} compact />
        </div>
      </div>
    </Tag>
  )
}
