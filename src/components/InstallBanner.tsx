import { useState } from 'react'
import { Share, SquarePlus, X } from 'lucide-react'
import { readString, writeString } from '@/lib/storage'

export function isStandalone(): boolean {
  return (
    window.matchMedia?.('(display-mode: standalone)').matches ||
    (navigator as Navigator & { standalone?: boolean }).standalone === true
  )
}

export function isIOS(): boolean {
  return /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
}

/** iOS Safari has no install prompt — teach the Share → Add to Home Screen gesture once. */
export function InstallBanner() {
  const [hidden, setHidden] = useState(() => readString('duit.installHint') === 'dismissed')
  if (hidden || !isIOS() || isStandalone()) return null
  return (
    <div className="bg-surface relative mx-4 mb-6 flex gap-3 rounded-[var(--radius-card)] p-4">
      <img src="/apple-touch-icon-180x180.png" alt="" className="size-12 shrink-0 rounded-[11px]" />
      <div className="min-w-0 pr-5 text-[15px] leading-5">
        <p className="font-semibold">Install Duit on your iPhone</p>
        <p className="text-label-2 mt-0.5">
          Tap <Share className="text-tint inline size-4 -translate-y-0.5" aria-label="Share" /> then{' '}
          <span className="text-label whitespace-nowrap">
            <SquarePlus className="inline size-4 -translate-y-0.5" aria-hidden /> Add to Home Screen
          </span>{' '}
          for full-screen, offline use and Face ID.
        </p>
      </div>
      <button
        type="button"
        aria-label="Dismiss"
        onClick={() => {
          writeString('duit.installHint', 'dismissed')
          setHidden(true)
        }}
        className="text-label-2 absolute top-3 right-3"
      >
        <X className="size-5" />
      </button>
    </div>
  )
}
