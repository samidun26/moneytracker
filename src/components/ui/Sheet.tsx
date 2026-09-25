import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { cn } from '@/lib/cn'
import { useDismissToast } from './Toast'

interface SheetProps {
  open: boolean
  onClose: () => void
  title?: string
  leading?: ReactNode
  trailing?: ReactNode
  children: ReactNode
  /** large = full-height sheet (forms, composer); auto = fits content */
  size?: 'large' | 'auto'
  /** Background: grouped (for list forms) or plain */
  tone?: 'grouped' | 'plain'
  labelledBy?: string
  className?: string
}

let openCount = 0

/**
 * Bottom sheet on phones (drag the grabber down to dismiss), centered
 * dialog on wide screens.
 */
export function Sheet({
  open,
  onClose,
  title,
  leading,
  trailing,
  children,
  size = 'large',
  tone = 'grouped',
  className,
}: SheetProps) {
  const [mounted, setMounted] = useState(open)
  const [closing, setClosing] = useState(false)
  const [drag, setDrag] = useState(0)
  const panel = useRef<HTMLDivElement>(null)
  const start = useRef<{ y: number; t: number } | null>(null)
  const restoreFocus = useRef<HTMLElement | null>(null)
  const onCloseRef = useRef(onClose)
  onCloseRef.current = onClose
  const dismissToast = useDismissToast()

  useEffect(() => {
    if (open) {
      // The last action's toast ("Saved · Rp 25.000") would sit on top of this
      // sheet's controls: on phones, right over the keypad's 0 key.
      dismissToast()
      restoreFocus.current = document.activeElement as HTMLElement
      setMounted(true)
      setClosing(false)
      setDrag(0)
    } else if (mounted) {
      setClosing(true)
      const t = setTimeout(() => {
        setMounted(false)
        setClosing(false)
        restoreFocus.current?.focus?.()
      }, 260)
      return () => clearTimeout(t)
    }
  }, [open]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!mounted) return
    openCount++
    document.documentElement.style.overflow = 'hidden'
    // True modal: the app behind the sheet can't be focused or read by VoiceOver.
    document.getElementById('root')?.setAttribute('inert', '')
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onCloseRef.current()
    window.addEventListener('keydown', onKey)
    requestAnimationFrame(() => panel.current?.focus({ preventScroll: true }))
    return () => {
      window.removeEventListener('keydown', onKey)
      if (--openCount === 0) {
        document.documentElement.style.overflow = ''
        document.getElementById('root')?.removeAttribute('inert')
      }
    }
  }, [mounted])

  if (!mounted) return null

  const onPointerDown = (e: React.PointerEvent) => {
    start.current = { y: e.clientY, t: performance.now() }
    ;(e.target as HTMLElement).setPointerCapture?.(e.pointerId)
  }
  const onPointerMove = (e: React.PointerEvent) => {
    if (!start.current) return
    setDrag(Math.max(0, e.clientY - start.current.y))
  }
  const onPointerUp = (e: React.PointerEvent) => {
    if (!start.current) return
    const dy = e.clientY - start.current.y
    const v = dy / Math.max(1, performance.now() - start.current.t)
    start.current = null
    if (dy > 140 || (dy > 40 && v > 0.6)) onClose()
    else setDrag(0)
  }

  return createPortal(
    <div className="fixed inset-0 z-50 flex items-end justify-center md:items-center md:p-6">
      <div
        aria-hidden
        onClick={onClose}
        className={cn(
          'absolute inset-0 bg-black/40 transition-opacity duration-300',
          closing ? 'opacity-0' : 'animate-[fade-in_250ms_ease-out]',
        )}
      />
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        style={{ transform: drag ? `translateY(${drag}px)` : undefined, transition: drag ? 'none' : undefined }}
        className={cn(
          'relative flex w-full flex-col overflow-hidden rounded-t-[12px] shadow-2xl outline-none md:max-w-lg md:rounded-[16px]',
          tone === 'grouped' ? 'bg-bg' : 'bg-surface',
          size === 'large'
            ? 'h-[calc(100dvh-env(safe-area-inset-top)-10px)] md:h-auto md:max-h-[88dvh]'
            : 'max-h-[calc(100dvh-env(safe-area-inset-top)-10px)] md:max-h-[88dvh]',
          closing
            ? 'translate-y-full transition-transform duration-[260ms] ease-[var(--ease-ios)] md:translate-y-0 md:scale-95 md:opacity-0 md:transition-[opacity,transform]'
            : 'animate-[sheet-in_380ms_var(--ease-ios)] md:animate-[pop-in_200ms_ease-out]',
          className,
        )}
      >
        {(title || leading || trailing) && (
          <div
            className="relative shrink-0 touch-none select-none"
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
          >
            <div aria-hidden className="bg-label-3 mx-auto mt-[5px] h-[5px] w-9 rounded-full md:hidden" />
            <div className="flex h-12 items-center justify-between px-4">
              <div className="flex min-w-16 justify-start" onPointerDown={(e) => e.stopPropagation()}>
                {leading}
              </div>
              {title && <h2 className="truncate px-2 text-[17px] font-semibold">{title}</h2>}
              <div className="flex min-w-16 justify-end" onPointerDown={(e) => e.stopPropagation()}>
                {trailing}
              </div>
            </div>
          </div>
        )}
        {children}
      </div>
    </div>,
    document.body,
  )
}

export function SheetButton({
  onClick,
  children,
  bold,
  disabled,
  destructive,
}: {
  onClick: () => void
  children: ReactNode
  bold?: boolean
  disabled?: boolean
  destructive?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={cn(
        'press -mx-2 rounded-lg px-2 py-1.5 text-[17px] disabled:opacity-35',
        destructive ? 'text-negative' : 'text-tint',
        bold && 'font-semibold',
      )}
    >
      {children}
    </button>
  )
}
