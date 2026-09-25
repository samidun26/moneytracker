import { Delete } from 'lucide-react'
import type { ReactNode } from 'react'
import { cn } from '@/lib/cn'
import { haptic } from '@/lib/haptics'
import { PIN_LENGTH } from './lock'

/** iOS passcode-style pad: dots + round keys. The bottom-left slot can hold a Face ID button. */
export function PinPad({
  value,
  onChange,
  error,
  extraKey,
  disabled,
}: {
  value: string
  onChange: (v: string) => void
  error?: boolean
  extraKey?: ReactNode
  disabled?: boolean
}) {
  const press = (d: string) => {
    if (disabled || value.length >= PIN_LENGTH) return
    haptic()
    onChange(value + d)
  }
  return (
    <div className="flex flex-col items-center">
      <div className={cn('mb-10 flex gap-4', error && 'animate-[shake_400ms]')} aria-label={`${value.length} of ${PIN_LENGTH} digits entered`} role="status">
        {Array.from({ length: PIN_LENGTH }, (_, i) => (
          <span
            key={i}
            className={cn('size-3.5 rounded-full border-[1.5px] transition-colors', i < value.length ? 'border-label bg-label' : 'border-label-2')}
          />
        ))}
      </div>
      <div className="grid grid-cols-3 gap-x-6 gap-y-4">
        {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((d) => (
          <Key key={d} onClick={() => press(d)} disabled={disabled}>
            {d}
          </Key>
        ))}
        <div className="flex size-[76px] items-center justify-center">{extraKey}</div>
        <Key onClick={() => press('0')} disabled={disabled}>
          0
        </Key>
        <button
          type="button"
          aria-label="Delete"
          onClick={() => onChange(value.slice(0, -1))}
          className={cn('flex size-[76px] items-center justify-center text-[17px]', !value && 'invisible')}
        >
          <Delete className="size-7" strokeWidth={1.6} />
        </button>
      </div>
    </div>
  )
}

function Key({ children, onClick, disabled }: { children: ReactNode; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className="bg-fill active:bg-fill-2 flex size-[76px] items-center justify-center rounded-full text-[34px] font-light transition-colors disabled:opacity-40"
      style={{ fontFamily: 'var(--font-rounded)' }}
    >
      {children}
    </button>
  )
}
