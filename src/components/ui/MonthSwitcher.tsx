import { ChevronLeft, ChevronRight } from 'lucide-react'
import { currentMonth, formatMonth, shiftMonth, type MonthKey } from '@/lib/dates'

export function MonthSwitcher({ month, onChange }: { month: MonthKey; onChange: (m: MonthKey) => void }) {
  const isCurrent = month >= currentMonth()
  return (
    <div className="flex items-center justify-between">
      <button
        type="button"
        aria-label="Previous month"
        onClick={() => onChange(shiftMonth(month, -1))}
        className="press text-tint bg-surface flex size-9 items-center justify-center rounded-full"
      >
        <ChevronLeft className="size-5" strokeWidth={2.4} />
      </button>
      <button
        type="button"
        onClick={() => onChange(currentMonth())}
        className="text-[17px] font-semibold"
        aria-live="polite"
      >
        {formatMonth(month)}
      </button>
      <button
        type="button"
        aria-label="Next month"
        disabled={isCurrent}
        onClick={() => onChange(shiftMonth(month, 1))}
        className="press text-tint bg-surface flex size-9 items-center justify-center rounded-full disabled:opacity-30"
      >
        <ChevronRight className="size-5" strokeWidth={2.4} />
      </button>
    </div>
  )
}
