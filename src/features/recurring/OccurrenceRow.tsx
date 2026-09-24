import { ArrowLeftRight } from 'lucide-react'
import { markOccurrencePaid, skipOccurrence } from '@/domain/recurringActions'
import type { Occurrence } from '@/domain/recurring'
import { useLedger } from '@/hooks/useLedger'
import { useToday } from '@/hooks/useToday'
import { cn } from '@/lib/cn'
import { formatDayLabel, formatRelativeDays } from '@/lib/dates'
import { formatCompact, formatNumber } from '@/lib/money'
import { IconBadge } from '@/components/ui/IconBadge'
import { useToast } from '@/components/ui/Toast'

export function OccurrenceRow({ o, onOpen }: { o: Occurrence; onOpen?: () => void }) {
  const { categoryById } = useLedger()
  const today = useToday()
  const toast = useToast()
  const cat = o.rule.categoryId ? categoryById.get(o.rule.categoryId) : undefined
  const title = o.rule.note || cat?.name || 'Transfer'
  const when =
    o.status === 'due'
      ? `${o.date === today ? 'Due today' : `Due ${formatRelativeDays(o.date, today)}`} · ${formatCompact(o.rule.amount)}`
      : `${formatDayLabel(o.date, today)} · ${o.rule.autoPost ? 'auto-logs' : 'reminder'}`

  return (
    <div className="group flex items-center gap-3 pl-4">
      <button type="button" onClick={onOpen} className="shrink-0" aria-label={`Edit ${title}`}>
        {o.rule.type === 'transfer' ? (
          <span className="bg-fill text-label-2 flex size-9 items-center justify-center rounded-[10px]">
            <ArrowLeftRight className="size-[18px]" />
          </span>
        ) : (
          <IconBadge icon={cat?.icon ?? '🔁'} color={cat?.color ?? 'gray'} />
        )}
      </button>
      <div className="row-sep flex min-h-[58px] min-w-0 flex-1 items-center gap-2 py-2 pr-4">
        <button type="button" onClick={onOpen} className="min-w-0 flex-1 text-left">
          <div className="truncate text-[16px] font-medium">{title}</div>
          <div className={cn('truncate text-[13px]', o.status === 'due' ? 'text-warning font-medium' : 'text-label-2')}>{when}</div>
        </button>
        {o.status === 'due' ? (
          <div className="flex shrink-0 items-center gap-1.5">
            <button
              type="button"
              onClick={async () => {
                await skipOccurrence(o.rule, o.date)
                toast({ message: `Skipped ${title}`, tone: 'info' })
              }}
              className="press text-label-2 h-8 rounded-full px-1.5 text-[13px] font-semibold"
            >
              Skip
            </button>
            <button
              type="button"
              onClick={async () => {
                await markOccurrencePaid(o.rule, o.date)
                toast({ message: `Logged ${title}` })
              }}
              className="press bg-tint-fill text-on-tint h-8 rounded-full px-3 text-[13px] font-semibold"
            >
              Paid
            </button>
          </div>
        ) : (
          <span className={cn('tabular shrink-0 text-[16px]', o.rule.type === 'income' ? 'text-positive' : 'text-label-2')}>
            {o.rule.type === 'income' ? '+' : o.rule.type === 'expense' ? '−' : ''}
            {formatNumber(o.rule.amount)}
          </span>
        )}
      </div>
    </div>
  )
}
