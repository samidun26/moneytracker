import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { CircleAlert, CircleCheck } from 'lucide-react'
import { cn } from '@/lib/cn'

interface ToastOptions {
  message: string
  tone?: 'success' | 'error' | 'info'
  action?: { label: string; onClick: () => void }
  duration?: number
}

const ToastContext = createContext<(t: ToastOptions) => void>(() => {})

export function useToast() {
  return useContext(ToastContext)
}

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<(ToastOptions & { id: number }) | null>(null)
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined)

  const show = useCallback((t: ToastOptions) => {
    clearTimeout(timer.current)
    setToast({ ...t, id: Date.now() })
    timer.current = setTimeout(() => setToast(null), t.duration ?? (t.action ? 5000 : 2600))
  }, [])

  return (
    <ToastContext.Provider value={show}>
      {children}
      {createPortal(
        <div
          aria-live="polite"
          className="pointer-events-none fixed inset-x-0 z-[70] flex justify-center px-4 md:bottom-6"
          style={{ bottom: 'calc(env(safe-area-inset-bottom) + 76px)' }}
        >
          {toast && (
            <div
              key={toast.id}
              role="status"
              className="glass pointer-events-auto flex max-w-md min-w-0 items-center gap-2.5 rounded-full py-2.5 pr-2.5 pl-4 shadow-[0_8px_30px_rgb(0_0_0/0.16)] animate-[toast-in_300ms_var(--ease-ios)]"
            >
              {toast.tone === 'error' ? (
                <CircleAlert className="text-negative size-5 shrink-0" aria-hidden />
              ) : (
                <CircleCheck className={cn('size-5 shrink-0', toast.tone === 'info' ? 'text-tint' : 'text-positive')} aria-hidden />
              )}
              <span className="truncate text-[15px] font-medium">{toast.message}</span>
              {toast.action ? (
                <button
                  type="button"
                  onClick={() => {
                    toast.action?.onClick()
                    setToast(null)
                  }}
                  className="bg-tint-soft text-tint ml-1 shrink-0 rounded-full px-3 py-1 text-[15px] font-semibold"
                >
                  {toast.action.label}
                </button>
              ) : (
                <span className="w-1.5" />
              )}
            </div>
          )}
        </div>,
        document.body,
      )}
    </ToastContext.Provider>
  )
}
