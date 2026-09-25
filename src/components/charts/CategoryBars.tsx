import type { CategorySlice } from '@/domain/insights'
import type { Category } from '@/db/types'
import { formatRp } from '@/lib/money'
import { IconBadge } from '@/components/ui/IconBadge'

/**
 * Ranked horizontal bars — one series, one hue. Each row is fully labeled
 * (name, amount, share, change), so the list doubles as the table view.
 */
export function CategoryBars({
  slices,
  categoryById,
  onSelect,
}: {
  slices: CategorySlice[]
  categoryById: Map<string, Category>
  onSelect?: (categoryId: string | null) => void
}) {
  const max = Math.max(1, ...slices.map((s) => s.amount))
  return (
    <ul className="space-y-3.5">
      {slices.map((s) => {
        const c = s.categoryId ? categoryById.get(s.categoryId) : undefined
        const change = s.previous > 0 ? (s.amount - s.previous) / s.previous : null
        return (
          <li key={s.categoryId ?? 'none'}>
            <button type="button" onClick={() => onSelect?.(s.categoryId)} className="flex w-full items-center gap-3 text-left">
              <IconBadge icon={c?.icon ?? '❔'} color={c?.color ?? 'gray'} size="sm" />
              <div className="min-w-0 flex-1">
                <div className="flex items-baseline gap-2">
                  <span className="min-w-0 flex-1 truncate text-[15px] font-medium">{c?.name ?? 'Uncategorized'}</span>
                  <span className="tabular shrink-0 text-[15px] font-medium">{formatRp(s.amount)}</span>
                </div>
                <div className="mt-1.5 flex items-center gap-2">
                  <div className="h-2 flex-1">
                    <div
                      className="h-full rounded-r-[4px]"
                      style={{ width: `${Math.max(2, (s.amount / max) * 100)}%`, background: 'var(--viz-expense)' }}
                    />
                  </div>
                  <span className="text-label-2 tabular w-[92px] shrink-0 text-right text-[12px]">
                    {Math.round(s.share * 100)}%
                    {change != null && Math.abs(change) >= 0.01 && (
                      <span className={change > 0 ? 'text-negative' : 'text-positive'}>
                        {' '}
                        {change > 0 ? '▲' : '▼'}
                        {Math.min(999, Math.abs(Math.round(change * 100)))}%
                      </span>
                    )}
                    {change == null && s.previous === 0 && <span> · new</span>}
                  </span>
                </div>
              </div>
            </button>
          </li>
        )
      })}
    </ul>
  )
}
