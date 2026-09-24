import { createContext, useCallback, useContext, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

interface ConfirmOptions {
  title: string
  message?: string
  confirmLabel: string
  destructive?: boolean
}

type ConfirmFn = (o: ConfirmOptions) => Promise<boolean>
const ConfirmContext = createContext<ConfirmFn>(async () => false)

export function useConfirm() {
  return useContext(ConfirmContext)
}

/** iOS action sheet for destructive confirmations (instead of window.confirm, which shows the domain). */
export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<(ConfirmOptions & { resolve: (v: boolean) => void }) | null>(null)

  const confirm = useCallback<ConfirmFn>((o) => new Promise((resolve) => setState({ ...o, resolve })), [])

  const close = (v: boolean) => {
    state?.resolve(v)
    setState(null)
  }

  return (
    <ConfirmContext.Provider value={confirm}>
      {children}
      {state &&
        createPortal(
          <div className="fixed inset-0 z-[80] flex items-end justify-center p-2 md:items-center" role="alertdialog" aria-modal="true" aria-label={state.title}>
            <div className="absolute inset-0 bg-black/40 animate-[fade-in_200ms_ease-out]" onClick={() => close(false)} aria-hidden />
            <div
              className="relative w-full max-w-md space-y-2 animate-[sheet-in_320ms_var(--ease-ios)] md:animate-[pop-in_180ms_ease-out]"
              style={{ marginBottom: 'env(safe-area-inset-bottom)' }}
            >
              <div className="glass overflow-hidden rounded-[14px] text-center">
                <div className="px-4 py-3.5">
                  <p className="text-label-2 text-[13px] font-semibold">{state.title}</p>
                  {state.message && <p className="text-label-2 mt-1 text-[13px]">{state.message}</p>}
                </div>
                <button
                  type="button"
                  autoFocus
                  onClick={() => close(true)}
                  className={`hairline-t row-press h-14 w-full text-[20px] ${state.destructive ? 'text-negative' : 'text-tint'}`}
                >
                  {state.confirmLabel}
                </button>
              </div>
              <button
                type="button"
                onClick={() => close(false)}
                className="bg-elevated text-tint row-press h-14 w-full rounded-[14px] text-[20px] font-semibold"
              >
                Cancel
              </button>
            </div>
          </div>,
          document.body,
        )}
    </ConfirmContext.Provider>
  )
}
