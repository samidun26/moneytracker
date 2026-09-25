import { useEffect, useRef, useState, type ReactNode } from 'react'
import { ChevronLeft } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { cn } from '@/lib/cn'

interface PageProps {
  title: string
  /** Back button: label shown next to the chevron (iOS shows the previous screen's title). */
  back?: { label: string; to?: string }
  /** Right side of the nav bar */
  actions?: ReactNode
  /** Rendered under the large title, e.g. a search field */
  subheader?: ReactNode
  children: ReactNode
  className?: string
}

/**
 * iOS-style screen: large title that collapses into the nav bar on scroll,
 * with a translucent bar that appears once content scrolls beneath it.
 */
export function Page({ title, back, actions, subheader, children, className }: PageProps) {
  const sentinel = useRef<HTMLDivElement>(null)
  const [collapsed, setCollapsed] = useState(false)
  const navigate = useNavigate()

  useEffect(() => {
    const el = sentinel.current
    if (!el) return
    const io = new IntersectionObserver(([e]) => setCollapsed(!e.isIntersecting), {
      rootMargin: '-52px 0px 0px 0px',
    })
    io.observe(el)
    return () => io.disconnect()
  }, [])

  return (
    <div className={cn('mx-auto w-full max-w-2xl', className)}>
      <header
        className={cn(
          'pt-safe sticky top-0 z-30 transition-[background-color,box-shadow] duration-200',
          collapsed ? 'glass hairline-b' : 'bg-bg',
        )}
      >
        <div className="relative flex h-11 items-center justify-between px-2">
          <div className="flex min-w-0 flex-1 items-center">
            {back && (
              <button
                type="button"
                onClick={() => (back.to ? navigate(back.to) : navigate(-1))}
                className="press text-tint -ml-1 flex items-center gap-0.5 rounded-lg px-1 py-1.5 text-[17px]"
              >
                <ChevronLeft className="size-7" strokeWidth={2.2} aria-hidden />
                <span className="-ml-1 truncate">{back.label}</span>
              </button>
            )}
          </div>
          <h2
            aria-hidden={!collapsed}
            className={cn(
              'pointer-events-none absolute inset-x-24 truncate text-center text-[17px] font-semibold transition-opacity duration-200',
              collapsed ? 'opacity-100' : 'opacity-0',
            )}
          >
            {title}
          </h2>
          <div className="flex flex-1 items-center justify-end gap-1 pr-1">{actions}</div>
        </div>
      </header>
      <div ref={sentinel} className="px-4 pt-0.5 pb-2">
        <h1 className="text-[34px] leading-[41px] font-bold tracking-[0.01em]">{title}</h1>
      </div>
      {subheader && <div className="px-4 pb-3">{subheader}</div>}
      <main className="pb-[calc(env(safe-area-inset-bottom)+96px)] md:pb-12">{children}</main>
    </div>
  )
}

export function NavButton({
  onClick,
  label,
  children,
  bold,
  disabled,
}: {
  onClick: () => void
  label: string
  children: ReactNode
  bold?: boolean
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      disabled={disabled}
      className={cn(
        'press text-tint flex h-9 min-w-9 items-center justify-center rounded-full px-2 text-[17px] disabled:opacity-35',
        bold && 'font-semibold',
      )}
    >
      {children}
    </button>
  )
}
