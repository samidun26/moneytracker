import { cn } from '@/lib/cn'

export function SegmentedControl<T extends string>({
  value,
  onChange,
  options,
  className,
  label,
}: {
  value: T
  onChange: (v: T) => void
  options: Array<{ value: T; label: string }>
  className?: string
  label: string
}) {
  const index = Math.max(0, options.findIndex((o) => o.value === value))
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className={cn('bg-fill relative grid h-8 rounded-[9px] p-[2px] text-[13px] font-medium select-none', className)}
      style={{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }}
    >
      <span
        aria-hidden
        className="bg-elevated absolute top-[2px] bottom-[2px] left-[2px] rounded-[7px] shadow-[0_3px_8px_rgb(0_0_0/0.12),0_3px_1px_rgb(0_0_0/0.04)] transition-transform duration-300 ease-[var(--ease-ios)]"
        style={{
          width: `calc((100% - 4px) / ${options.length})`,
          transform: `translateX(${index * 100}%)`,
        }}
      />
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          role="radio"
          aria-checked={o.value === value}
          onClick={() => onChange(o.value)}
          className={cn('relative z-10 rounded-[7px] transition-colors', o.value === value ? 'font-semibold' : 'text-label')}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}
