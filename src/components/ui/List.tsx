import type { ReactNode } from 'react'
import { ChevronRight } from 'lucide-react'
import { Link } from 'react-router-dom'
import { cn } from '@/lib/cn'

/** Inset grouped section — the core iOS list container. */
export function ListGroup({
  header,
  footer,
  children,
  className,
  action,
}: {
  header?: ReactNode
  footer?: ReactNode
  children: ReactNode
  className?: string
  /** Right-aligned header action, e.g. "See all" */
  action?: ReactNode
}) {
  return (
    <section className={cn('mx-4 mb-8', className)}>
      {(header || action) && (
        <div className="mb-1.5 flex items-end justify-between px-4">
          {header && <h3 className="text-label-2 text-[13px] uppercase tracking-[0.02em]">{header}</h3>}
          {action && <div className="text-[15px]">{action}</div>}
        </div>
      )}
      <div className="bg-surface overflow-hidden rounded-[var(--radius-card)]">{children}</div>
      {footer && <p className="text-label-2 mt-1.5 px-4 text-[13px] leading-[18px]">{footer}</p>}
    </section>
  )
}

interface ListRowProps {
  leading?: ReactNode
  title: ReactNode
  subtitle?: ReactNode
  value?: ReactNode
  trailing?: ReactNode
  to?: string
  onClick?: () => void
  chevron?: boolean
  destructive?: boolean
  tinted?: boolean
  className?: string
}

/** One row in a ListGroup. Renders as link, button, or static row. */
export function ListRow({
  leading,
  title,
  subtitle,
  value,
  trailing,
  to,
  onClick,
  chevron,
  destructive,
  tinted,
  className,
}: ListRowProps) {
  const showChevron = chevron ?? !!to
  const content = (
    <>
      {leading && <div className="shrink-0">{leading}</div>}
      <div className="row-sep flex min-h-11 min-w-0 flex-1 items-center gap-3 py-2.5 pr-4">
        <div className="min-w-0 flex-1">
          <div
            className={cn(
              'truncate text-[17px]',
              destructive && 'text-negative',
              tinted && 'text-tint',
            )}
          >
            {title}
          </div>
          {subtitle && <div className="text-label-2 mt-0.5 truncate text-[13px]">{subtitle}</div>}
        </div>
        {value != null && <div className="text-label-2 shrink-0 text-[17px]">{value}</div>}
        {trailing}
        {showChevron && <ChevronRight className="text-label-3 -mr-1 size-5 shrink-0" strokeWidth={2.4} aria-hidden />}
      </div>
    </>
  )
  const base = cn('group flex w-full items-center gap-3 pl-4 text-left', className)
  if (to)
    return (
      <Link to={to} className={cn(base, 'row-press')}>
        {content}
      </Link>
    )
  if (onClick)
    return (
      <button type="button" onClick={onClick} className={cn(base, 'row-press')}>
        {content}
      </button>
    )
  return <div className={base}>{content}</div>
}
