import { Delete } from 'lucide-react'
import { useRef } from 'react'
import { haptic } from '@/lib/haptics'

export type KeypadKey = '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '000' | 'back' | 'clear'

const KEYS: KeypadKey[] = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', 'back']

/** Numeric keypad with a "000" key — most rupiah amounts end in thousands. Long-press ⌫ clears. */
export function Keypad({ onKey }: { onKey: (k: KeypadKey) => void }) {
  const hold = useRef<ReturnType<typeof setTimeout>>(undefined)
  const held = useRef(false)

  return (
    <div className="grid grid-cols-3 gap-1.5" role="group" aria-label="Amount keypad">
      {KEYS.map((k) => (
        <button
          key={k}
          type="button"
          aria-label={k === 'back' ? 'Delete digit (hold to clear)' : k}
          onPointerDown={() => {
            if (k !== 'back') return
            held.current = false
            hold.current = setTimeout(() => {
              held.current = true
              haptic()
              onKey('clear')
            }, 450)
          }}
          onPointerUp={() => clearTimeout(hold.current)}
          onPointerLeave={() => clearTimeout(hold.current)}
          onClick={() => {
            if (k === 'back' && held.current) return
            haptic()
            onKey(k)
          }}
          className="bg-surface active:bg-fill-2 flex h-[50px] items-center justify-center rounded-[10px] text-[25px] font-normal shadow-[0_1px_0_rgb(0_0_0/0.08)] transition-colors select-none"
          style={{ fontFamily: 'var(--font-rounded)' }}
        >
          {k === 'back' ? <Delete className="size-6" strokeWidth={1.8} /> : k}
        </button>
      ))}
    </div>
  )
}

/** Pure reducer so it's testable: applies a key to an amount. */
export function applyKey(amount: number, key: KeypadKey, max = 999_999_999_999): number {
  if (key === 'clear') return 0
  if (key === 'back') return Math.floor(amount / 10)
  const next = Number(String(amount === 0 ? '' : amount) + key)
  return next > max ? amount : next
}
