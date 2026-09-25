import { useState } from 'react'
import { Check, CloudDownload, Lock, Plus, WifiOff } from 'lucide-react'
import { upsert } from '@/db/repo'
import type { AccountType, ColorName } from '@/db/types'
import { cn } from '@/lib/cn'
import { writeString } from '@/lib/storage'
import { Button } from '@/components/ui/Button'
import { AmountInput } from '@/components/ui/Fields'
import { IconBadge } from '@/components/ui/IconBadge'

interface Draft {
  on: boolean
  name: string
  type: AccountType
  icon: string
  color: ColorName
  balance: number
  hint: string
}

const START: Draft[] = [
  { on: true, name: 'Cash', type: 'cash', icon: '💵', color: 'green', balance: 0, hint: 'Money in your wallet' },
  { on: true, name: 'BCA', type: 'bank', icon: '🏦', color: 'blue', balance: 0, hint: 'Main bank account' },
  { on: true, name: 'GoPay', type: 'ewallet', icon: '📱', color: 'teal', balance: 0, hint: 'E-wallet' },
  { on: false, name: 'Credit card', type: 'credit', icon: '💳', color: 'purple', balance: 0, hint: 'Enter what you owe' },
]

/** First run: welcome → accounts with current balances → go. */
export function OnboardingPage({ onDone, onRestore }: { onDone: () => void; onRestore: () => void }) {
  const [step, setStep] = useState<'welcome' | 'accounts'>('welcome')
  const [drafts, setDrafts] = useState(START)
  const [busy, setBusy] = useState(false)
  const set = (i: number, patch: Partial<Draft>) => setDrafts((d) => d.map((x, j) => (j === i ? { ...x, ...patch } : x)))
  const chosen = drafts.filter((d) => d.on && d.name.trim())

  const finish = async () => {
    setBusy(true)
    let order = 0
    for (const d of chosen) {
      await upsert('accounts', {
        name: d.name.trim(),
        type: d.type,
        icon: d.icon,
        color: d.color,
        openingBalance: d.type === 'credit' ? -Math.abs(d.balance) : d.balance,
        archived: false,
        order: order++,
      })
    }
    writeString('duit.onboarded', '1')
    onDone()
  }

  if (step === 'welcome')
    return (
      <div className="pt-safe pb-safe mx-auto flex min-h-dvh max-w-md flex-col px-6">
        <div className="flex flex-1 flex-col justify-center py-10">
          <img src="/favicon.svg" alt="" className="mb-6 size-20 drop-shadow-[0_10px_24px_rgb(88_86_214/0.35)]" />
          <h1 className="text-[40px] leading-[46px] font-bold tracking-tight">
            Know where every
            <br />
            rupiah goes.
          </h1>
          <p className="text-label-2 mt-3 text-[17px]">A calm, fast money tracker for your iPhone and the web.</p>
          <ul className="mt-9 space-y-5">
            {[
              { icon: Plus, title: 'Log it in 3 seconds', body: 'Big keypad with a 000 key, one tap per category.' },
              { icon: WifiOff, title: 'Works offline', body: 'Everything saves on your device instantly and syncs later.' },
              { icon: Lock, title: 'Private by design', body: 'Face ID lock. Your data syncs only to your own cloud.' },
            ].map((f) => (
              <li key={f.title} className="flex gap-4">
                <span className="bg-tint-soft text-tint flex size-11 shrink-0 items-center justify-center rounded-[12px]">
                  <f.icon className="size-[22px]" strokeWidth={2.2} />
                </span>
                <div>
                  <p className="text-[17px] font-semibold">{f.title}</p>
                  <p className="text-label-2 text-[15px]">{f.body}</p>
                </div>
              </li>
            ))}
          </ul>
        </div>
        <div className="space-y-2 pb-6">
          <Button block onClick={() => setStep('accounts')}>
            Get started
          </Button>
          <Button block variant="plain" onClick={onRestore}>
            <CloudDownload className="size-5" /> I already use Duit on another device
          </Button>
        </div>
      </div>
    )

  return (
    <div className="pt-safe pb-safe mx-auto flex min-h-dvh max-w-md flex-col">
      <div className="px-6 pt-10 pb-6">
        <p className="text-tint text-[15px] font-semibold">Step 1 of 1</p>
        <h1 className="mt-1 text-[32px] leading-[38px] font-bold tracking-tight">Where’s your money?</h1>
        <p className="text-label-2 mt-2 text-[15px]">Pick your accounts and enter today’s balances. You can rename or add more anytime.</p>
      </div>
      <div className="flex-1 space-y-3 px-4">
        {drafts.map((d, i) => (
          <div key={i} className={cn('bg-surface rounded-[var(--radius-card)] transition-opacity', !d.on && 'opacity-60')}>
            <div className="flex items-center gap-3 p-3">
              <button
                type="button"
                role="checkbox"
                aria-checked={d.on}
                aria-label={`Use ${d.name}`}
                onClick={() => set(i, { on: !d.on })}
                className={cn('flex size-6 shrink-0 items-center justify-center rounded-full border-2', d.on ? 'bg-tint-fill border-tint-fill' : 'border-label-3')}
              >
                {d.on && <Check className="size-3.5 text-white" strokeWidth={3.5} />}
              </button>
              <IconBadge icon={d.icon} color={d.color} />
              <div className="min-w-0 flex-1">
                <input
                  value={d.name}
                  onChange={(e) => set(i, { name: e.target.value, on: true })}
                  aria-label="Account name"
                  className="w-full bg-transparent text-[17px] font-medium outline-none"
                />
                <p className="text-label-2 text-[12px]">{d.hint}</p>
              </div>
            </div>
            {d.on && (
              <div className="hairline-t flex items-center justify-between px-3 py-1 pl-[84px]">
                <span className="text-label-2 text-[15px]">{d.type === 'credit' ? 'Owed' : 'Balance'}</span>
                <AmountInput value={d.balance} onChange={(v) => set(i, { balance: v })} />
              </div>
            )}
          </div>
        ))}
      </div>
      <div className="px-6 pt-6 pb-6">
        <Button block disabled={!chosen.length || busy} onClick={finish}>
          {chosen.length ? `Create ${chosen.length} account${chosen.length === 1 ? '' : 's'}` : 'Choose at least one'}
        </Button>
      </div>
    </div>
  )
}
