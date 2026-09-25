import { ChevronsUpDown } from 'lucide-react'
import { Toggle } from './Toggle'
import type { InputHTMLAttributes, ReactNode } from 'react'
import { cn } from '@/lib/cn'
import { formatNumber, parseAmount, parseSignedAmount } from '@/lib/money'

/** Row with a label on the left and a control on the right — iOS form style. */
export function FieldRow({ label, children, htmlFor }: { label: string; children: ReactNode; htmlFor?: string }) {
  return (
    <div className="group flex items-center pl-4">
      <div className="row-sep flex min-h-11 flex-1 items-center gap-3 pr-4">
        <label htmlFor={htmlFor} className="shrink-0 text-[17px]">
          {label}
        </label>
        <div className="flex min-w-0 flex-1 justify-end">{children}</div>
      </div>
    </div>
  )
}

export function TextInput({ className, ...rest }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      {...rest}
      className={cn(
        'placeholder:text-label-3 text-label-2 focus:text-label w-full min-w-0 bg-transparent py-2.5 text-right text-[17px] outline-none',
        className,
      )}
    />
  )
}

/** Full-width text input row (no label) — for names and notes. */
export function PlainInputRow({ className, ...rest }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="group flex items-center pl-4">
      <div className="row-sep flex min-h-11 flex-1 items-center pr-4">
        <input
          {...rest}
          className={cn('placeholder:text-label-3 w-full bg-transparent py-2.5 text-[17px] outline-none', className)}
        />
      </div>
    </div>
  )
}

/** Rupiah input: shows thousands separators while typing, emits an integer. */
export function AmountInput({
  value,
  onChange,
  allowNegative,
  id,
  placeholder = '0',
  autoFocus,
}: {
  value: number
  onChange: (v: number) => void
  allowNegative?: boolean
  id?: string
  placeholder?: string
  autoFocus?: boolean
}) {
  const text = value === 0 ? '' : `${value < 0 ? '-' : ''}${formatNumber(value)}`
  return (
    <div className="text-label-2 flex items-center justify-end gap-1 text-[17px]">
      <span>Rp</span>
      <input
        id={id}
        inputMode={allowNegative ? 'text' : 'numeric'}
        autoFocus={autoFocus}
        value={text}
        placeholder={placeholder}
        onChange={(e) => onChange(allowNegative ? parseSignedAmount(e.target.value) : parseAmount(e.target.value))}
        className="placeholder:text-label-3 text-label w-36 bg-transparent py-2.5 text-right outline-none tabular"
      />
    </div>
  )
}

/** Native <select> (iOS shows the wheel picker) disguised as a value + chevron. */
export function SelectRow<T extends string>({
  label,
  value,
  onChange,
  options,
  display,
  leading,
}: {
  label: string
  value: T
  onChange: (v: T) => void
  options: Array<{ value: T; label: string }>
  display?: ReactNode
  leading?: ReactNode
}) {
  const current = options.find((o) => o.value === value)
  return (
    <div className="group row-press relative flex items-center gap-3 pl-4">
      {leading}
      <div className="row-sep flex min-h-11 flex-1 items-center gap-3 pr-3">
        <span className="flex-1 text-[17px]">{label}</span>
        <span className="text-label-2 flex min-w-0 items-center gap-1 text-[17px]">
          <span className="truncate">{display ?? current?.label}</span>
          <ChevronsUpDown className="size-4 shrink-0" aria-hidden />
        </span>
      </div>
      <select
        aria-label={label}
        value={value}
        onChange={(e) => onChange(e.target.value as T)}
        className="absolute inset-0 cursor-pointer opacity-0"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </div>
  )
}

/** Native date picker disguised as a value row. */
export function DateRow({
  label,
  value,
  onChange,
  display,
  min,
  optional,
}: {
  label: string
  value: string | null
  onChange: (v: string | null) => void
  display: ReactNode
  min?: string
  optional?: boolean
}) {
  return (
    <div className="group row-press relative flex items-center pl-4">
      <div className="row-sep flex min-h-11 flex-1 items-center gap-3 pr-4">
        <span className="flex-1 text-[17px]">{label}</span>
        <span className="bg-fill rounded-md px-2.5 py-1 text-[17px]">{display}</span>
      </div>
      <input
        type="date"
        aria-label={label}
        value={value ?? ''}
        min={min}
        required={!optional}
        onChange={(e) => onChange(e.target.value || (optional ? null : value))}
        className="absolute inset-0 cursor-pointer opacity-0"
      />
    </div>
  )
}

export function ToggleRow({
  label,
  checked,
  onChange,
  leading,
  subtitle,
  disabled,
}: {
  label: string
  checked: boolean
  onChange: (v: boolean) => void
  leading?: ReactNode
  subtitle?: ReactNode
  disabled?: boolean
}) {
  return (
    <div className="group flex items-center gap-3 pl-4">
      {leading}
      <div className="row-sep flex min-h-11 flex-1 items-center gap-3 py-1.5 pr-4">
        <div className="min-w-0 flex-1">
          <div className="text-[17px]">{label}</div>
          {subtitle && <div className="text-label-2 text-[13px]">{subtitle}</div>}
        </div>
        <Toggle checked={checked} onChange={onChange} label={label} disabled={disabled} />
      </div>
    </div>
  )
}
