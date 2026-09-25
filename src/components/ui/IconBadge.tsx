import { colorSoft } from '@/lib/colors'
import { cn } from '@/lib/cn'

/** Emoji on a soft tinted rounded square — identity marker for categories & accounts. */
export function IconBadge({
  icon,
  color,
  size = 'md',
  className,
}: {
  icon: string
  color: string
  size?: 'sm' | 'md' | 'lg'
  className?: string
}) {
  const dims = { sm: 'size-7 text-[15px] rounded-[7px]', md: 'size-9 text-[19px] rounded-[10px]', lg: 'size-12 text-[26px] rounded-[13px]' }[size]
  return (
    <span
      aria-hidden
      className={cn('inline-flex shrink-0 items-center justify-center leading-none select-none', dims, className)}
      style={{ background: colorSoft(color) }}
    >
      {icon}
    </span>
  )
}

/** Solid glyph badge for settings rows (white Lucide icon on a system color). */
export function GlyphBadge({ children, color }: { children: React.ReactNode; color: string }) {
  return (
    <span
      aria-hidden
      className="inline-flex size-[29px] shrink-0 items-center justify-center rounded-[7px] text-white"
      style={{ background: `var(--sys-${color})` }}
    >
      {children}
    </span>
  )
}
