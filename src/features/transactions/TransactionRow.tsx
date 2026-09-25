import { ArrowLeftRight, Repeat } from 'lucide-react'
import type { Transaction } from '@/db/types'
import { useLedger } from '@/hooks/useLedger'
import { cn } from '@/lib/cn'
import { formatNumber } from '@/lib/money'
import { IconBadge } from '@/components/ui/IconBadge'
import { useComposer } from './Composer'

/**
 * One transaction. Expenses use normal ink (most rows are expenses — a wall
 * of red is noise); income is green with "+"; transfers are neutral.
 * `perspective` shows a transfer's direction relative to one account.
 */
export function TransactionRow({ tx, perspective }: { tx: Transaction; perspective?: string }) {
  const { categoryById, accountById } = useLedger()
  const compose = useComposer()
  const cat = tx.categoryId ? categoryById.get(tx.categoryId) : undefined
  const from = accountById.get(tx.accountId)
  const to = tx.toAccountId ? accountById.get(tx.toAccountId) : undefined

  const isTransfer = tx.type === 'transfer'
  const title = tx.note || (isTransfer ? 'Transfer' : (cat?.name ?? 'Uncategorized'))
  const subtitle = isTransfer
    ? `${from?.name ?? '—'} → ${to?.name ?? '—'}`
    : [tx.note ? cat?.name : null, from?.name].filter(Boolean).join(' · ')

  let sign = ''
  let tone = 'text-label'
  if (tx.type === 'income') {
    sign = '+'
    tone = 'text-positive'
  } else if (tx.type === 'expense') {
    sign = '−'
  } else if (perspective) {
    sign = tx.accountId === perspective ? '−' : '+'
    tone = tx.accountId === perspective ? 'text-label' : 'text-positive'
  } else {
    tone = 'text-label-2'
  }

  return (
    <button type="button" onClick={() => compose({ tx })} className="group row-press flex w-full items-center gap-3 pl-4 text-left">
      {isTransfer ? (
        <span className="bg-fill text-label-2 flex size-9 shrink-0 items-center justify-center rounded-[10px]">
          <ArrowLeftRight className="size-[18px]" strokeWidth={2.2} aria-hidden />
        </span>
      ) : (
        <IconBadge icon={cat?.icon ?? '❔'} color={cat?.color ?? 'gray'} />
      )}
      <div className="row-sep flex min-h-[58px] min-w-0 flex-1 items-center gap-2 py-2 pr-4">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-1.5">
            <span className="truncate text-[16px] font-medium">{title}</span>
            {tx.recurringId && <Repeat className="text-label-3 size-3.5 shrink-0" aria-label="Recurring" />}
          </div>
          {subtitle && <div className="text-label-2 truncate text-[13px]">{subtitle}</div>}
        </div>
        <span className={cn('tabular shrink-0 text-[16px] font-medium', tone)}>
          {sign}
          {formatNumber(tx.amount)}
        </span>
      </div>
    </button>
  )
}
