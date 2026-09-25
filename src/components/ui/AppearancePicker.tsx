import { useState } from 'react'
import { Check } from 'lucide-react'
import { COLOR_NAMES, type ColorName } from '@/db/types'
import { colorSoft, colorVar } from '@/lib/colors'
import { cn } from '@/lib/cn'

const firstGrapheme = (s: string) => {
  const Seg = (Intl as unknown as { Segmenter?: new (l?: string, o?: { granularity: string }) => { segment: (s: string) => Iterable<{ segment: string }> } }).Segmenter
  if (Seg) for (const { segment } of new Seg(undefined, { granularity: 'grapheme' }).segment(s)) return segment
  return [...s][0] ?? ''
}

/** Emoji + color picker with a live preview badge. Any emoji can be typed via the keyboard. */
export function AppearancePicker({
  icon,
  color,
  onIcon,
  onColor,
  presets,
}: {
  icon: string
  color: ColorName
  onIcon: (v: string) => void
  onColor: (v: ColorName) => void
  presets: string[]
}) {
  const [custom, setCustom] = useState('')
  return (
    <div className="space-y-4 p-4">
      <div className="flex items-center gap-4">
        <span
          className="flex size-16 shrink-0 items-center justify-center rounded-[18px] text-[34px]"
          style={{ background: colorSoft(color, 22) }}
          aria-hidden
        >
          {icon}
        </span>
        <label className="bg-fill flex h-11 flex-1 items-center gap-2 rounded-[10px] px-3">
          <span className="text-label-2 text-[15px]">Emoji</span>
          <input
            value={custom}
            onChange={(e) => {
              const g = firstGrapheme(e.target.value.trim())
              setCustom(g)
              if (g) onIcon(g)
            }}
            placeholder="Type any emoji"
            aria-label="Custom emoji"
            className="placeholder:text-label-3 min-w-0 flex-1 bg-transparent text-[17px] outline-none"
          />
        </label>
      </div>
      <div className="grid grid-cols-8 gap-1.5" role="radiogroup" aria-label="Icon">
        {presets.map((e) => (
          <button
            key={e}
            type="button"
            role="radio"
            aria-checked={e === icon}
            aria-label={e}
            onClick={() => onIcon(e)}
            className={cn('press flex aspect-square items-center justify-center rounded-[10px] text-[22px]', e === icon ? 'bg-tint-soft ring-tint ring-2' : 'bg-fill')}
          >
            {e}
          </button>
        ))}
      </div>
      <div className="flex flex-wrap gap-2.5" role="radiogroup" aria-label="Color">
        {COLOR_NAMES.map((c) => (
          <button
            key={c}
            type="button"
            role="radio"
            aria-checked={c === color}
            aria-label={c}
            onClick={() => onColor(c)}
            className="press flex size-8 items-center justify-center rounded-full"
            style={{ background: colorVar(c) }}
          >
            {c === color && <Check className="size-4 text-white" strokeWidth={3.5} />}
          </button>
        ))}
      </div>
    </div>
  )
}

export const ACCOUNT_EMOJI = ['💵', '🏦', '💳', '📱', '🐷', '💰', '🪙', '👛', '🏧', '📈', '💼', '🧾', '🏠', '🚗', '💎', '🌏']

export const CATEGORY_EMOJI = [
  '🍜', '🍛', '🍔', '🍱', '☕', '🧋', '🍺', '🛒',
  '🛵', '🚗', '🚆', '⛽', '🅿️', '🏠', '💡', '💧',
  '📶', '📱', '📺', '🎮', '🎬', '🎵', '🛍️', '👕',
  '💄', '💇', '💊', '🏥', '🏋️', '📚', '🎓', '👶',
  '👨‍👩‍👧', '🐶', '🎁', '🙏', '🕌', '✈️', '🏖️', '🔧',
  '🚬', '🎯', '💼', '🎉', '💻', '📈', '↩️', '📦',
]
