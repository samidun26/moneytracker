import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { ArrowDownUp, CalendarDays, ChevronDown, Trash2 } from 'lucide-react'
import { remove, restore, upsert } from '@/db/repo'
import type { Account, Transaction, TxType } from '@/db/types'
import { useLedger } from '@/hooks/useLedger'
import { cn } from '@/lib/cn'
import { addDays, formatDayLabel, todayISO, type ISODate } from '@/lib/dates'
import { haptic } from '@/lib/haptics'
import { formatNumber, formatRp } from '@/lib/money'
import { readString, writeString } from '@/lib/storage'
import { Button } from '@/components/ui/Button'
import { IconBadge } from '@/components/ui/IconBadge'
import { applyKey, Keypad, type KeypadKey } from '@/components/ui/Keypad'
import { SegmentedControl } from '@/components/ui/SegmentedControl'
import { Sheet, SheetButton } from '@/components/ui/Sheet'
import { useToast } from '@/components/ui/Toast'

interface OpenOptions {
  type?: TxType
  tx?: Transaction
  accountId?: string
}

const ComposerContext = createContext<(o?: OpenOptions) => void>(() => {})

/** Open the add/edit transaction sheet from anywhere. */
export function useComposer() {
  return useContext(ComposerContext)
}

export function ComposerProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<{ open: boolean; opts: OpenOptions; key: number }>({
    open: false,
    opts: {},
    key: 0,
  })
  const open = useCallback((opts: OpenOptions = {}) => setState((s) => ({ open: true, opts, key: s.key + 1 })), [])
  const close = useCallback(() => setState((s) => ({ ...s, open: false })), [])
  return (
    <ComposerContext.Provider value={open}>
      {children}
      <Sheet open={state.open} onClose={close} size="large" tone="grouped" title={undefined}>
        <ComposerBody key={state.key} opts={state.opts} onDone={close} />
      </Sheet>
    </ComposerContext.Provider>
  )
}

const TYPE_OPTIONS: Array<{ value: TxType; label: string }> = [
  { value: 'expense', label: 'Expense' },
  { value: 'income', label: 'Income' },
  { value: 'transfer', label: 'Transfer' },
]

const LAST_ACCOUNT = 'duit.lastAccount'

function ComposerBody({ opts, onDone }: { opts: OpenOptions; onDone: () => void }) {
  const { activeAccounts, accounts, categories } = useLedger()
  const toast = useToast()
  const editing = opts.tx
  const today = todayISO()

  const defaultAccount = useMemo(() => {
    const last = readString(LAST_ACCOUNT)
    return opts.accountId ?? (activeAccounts.find((a) => a.id === last) ?? activeAccounts[0])?.id ?? ''
  }, [activeAccounts, opts.accountId])

  const [type, setType] = useState<TxType>(editing?.type ?? opts.type ?? 'expense')
  const [amount, setAmount] = useState(editing?.amount ?? 0)
  const [categoryId, setCategoryId] = useState<string | null>(editing?.categoryId ?? null)
  const [accountId, setAccountId] = useState(editing?.accountId ?? defaultAccount)
  const [toAccountId, setToAccountId] = useState<string>(
    editing?.toAccountId ?? activeAccounts.find((a) => a.id !== (editing?.accountId ?? defaultAccount))?.id ?? '',
  )
  const [date, setDate] = useState<ISODate>(editing?.date ?? today)
  const [note, setNote] = useState(editing?.note ?? '')
  const [noteFocused, setNoteFocused] = useState(false)
  const [shake, setShake] = useState(false)

  // Accounts shown in pickers: active ones plus whichever is already selected (e.g. archived, when editing)
  const pickable = useMemo(
    () => accounts.filter((a) => !a.archived || a.id === accountId || a.id === toAccountId),
    [accounts, accountId, toAccountId],
  )
  const kindCategories = useMemo(() => categories.filter((c) => c.kind === (type === 'income' ? 'income' : 'expense')), [categories, type])

  const changeType = (t: TxType) => {
    setType(t)
    if (t !== 'transfer' && categoryId && !categories.find((c) => c.id === categoryId && c.kind === t)) setCategoryId(null)
  }

  const problem =
    amount <= 0
      ? 'Enter an amount'
      : !accountId
        ? 'Add an account first'
        : type === 'transfer'
          ? !toAccountId || toAccountId === accountId
            ? 'Pick two different accounts'
            : null
          : !categoryId
            ? 'Pick a category'
            : null

  const save = async () => {
    if (problem) {
      setShake(true)
      setTimeout(() => setShake(false), 420)
      return
    }
    await upsert('transactions', {
      id: editing?.id,
      type,
      amount,
      accountId,
      toAccountId: type === 'transfer' ? toAccountId : null,
      categoryId: type === 'transfer' ? null : categoryId,
      date,
      note: note.trim(),
      recurringId: editing?.recurringId ?? null,
    })
    writeString(LAST_ACCOUNT, accountId)
    haptic()
    toast({ message: `${editing ? 'Updated' : 'Saved'} · ${formatRp(amount)}` })
    onDone()
  }

  const del = async () => {
    if (!editing) return
    const removed = await remove('transactions', [editing.id])
    onDone()
    toast({ message: 'Transaction deleted', action: { label: 'Undo', onClick: () => void restore('transactions', removed) } })
  }

  const onKey = (k: KeypadKey) => setAmount((a) => applyKey(a, k))

  // Hardware keyboard support (web / iPad)
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (noteFocused || e.metaKey || e.ctrlKey || (e.target as HTMLElement)?.tagName === 'INPUT') return
      if (/^\d$/.test(e.key)) onKey(e.key as KeypadKey)
      else if (e.key === 'Backspace') onKey('back')
      else if (e.key === 'Enter') void save()
      else return
      e.preventDefault()
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  })

  const typeLabel = editing ? `Edit ${type}` : type === 'expense' ? 'New expense' : type === 'income' ? 'New income' : 'New transfer'
  const amountText = formatNumber(amount)

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      {/* Header */}
      <div aria-hidden className="bg-label-3 mx-auto mt-[5px] h-[5px] w-9 rounded-full md:hidden" />
      <div className="flex h-12 shrink-0 items-center justify-between px-4">
        <SheetButton onClick={onDone}>Cancel</SheetButton>
        <h2 className="text-[17px] font-semibold">{typeLabel}</h2>
        {editing ? (
          <button type="button" onClick={del} aria-label="Delete transaction" className="press text-negative -mr-1 p-1">
            <Trash2 className="size-[22px]" />
          </button>
        ) : (
          <span className="w-14" />
        )}
      </div>

      <div className="shrink-0 px-4">
        <SegmentedControl label="Transaction type" value={type} onChange={changeType} options={TYPE_OPTIONS} />
      </div>

      {/* Amount */}
      <div className="shrink-0 px-4 pt-4 pb-2 text-center" aria-live="polite">
        <div
          className={cn(
            'tabular-nums inline-flex items-baseline justify-center gap-1.5 font-semibold tracking-tight transition-colors',
            amount === 0 ? 'text-label-3' : type === 'income' ? 'text-positive' : 'text-label',
            amountText.length > 11 ? 'text-[34px]' : amountText.length > 8 ? 'text-[40px]' : 'text-[48px]',
            shake && problem === 'Enter an amount' && 'animate-[shake_400ms]',
          )}
          style={{ fontFamily: 'var(--font-rounded)' }}
        >
          <span className="text-label-2 text-[0.5em] font-medium">Rp</span>
          {amountText}
        </div>
      </div>

      {/* Category grid / transfer accounts */}
      <div className={cn('min-h-0 flex-1 overflow-y-auto px-4 pb-2', shake && problem !== 'Enter an amount' && 'animate-[shake_400ms]')}>
        {type === 'transfer' ? (
          <TransferPicker
            accounts={pickable}
            from={accountId}
            to={toAccountId}
            onFrom={setAccountId}
            onTo={setToAccountId}
          />
        ) : (
          <div className="grid grid-cols-4 gap-x-1 gap-y-2" role="radiogroup" aria-label="Category">
            {kindCategories.map((c) => {
              const selected = c.id === categoryId
              return (
                <button
                  key={c.id}
                  type="button"
                  role="radio"
                  aria-checked={selected}
                  onClick={() => {
                    setCategoryId(c.id)
                    haptic()
                  }}
                  className={cn(
                    'press flex flex-col items-center gap-1 rounded-[12px] px-0.5 py-2',
                    selected ? 'bg-surface ring-tint ring-2' : '',
                  )}
                >
                  <IconBadge icon={c.icon} color={c.color} size="md" />
                  <span className={cn('line-clamp-2 text-center text-[11.5px] leading-[14px]', selected ? 'font-semibold' : 'text-label-2')}>
                    {c.name}
                  </span>
                </button>
              )
            })}
          </div>
        )}
      </div>

      {/* Details: account, date, note */}
      <div className="hairline-t shrink-0 space-y-2 px-4 pt-2.5">
        <div className="flex gap-2">
          {type !== 'transfer' && (
            <Chip label="Account">
              <span className="truncate">{accountName(pickable, accountId)}</span>
              <ChevronDown className="text-label-2 size-4 shrink-0" />
              <select
                aria-label="Account"
                value={accountId}
                onChange={(e) => setAccountId(e.target.value)}
                className="absolute inset-0 opacity-0"
              >
                {pickable.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.icon} {a.name}
                  </option>
                ))}
              </select>
            </Chip>
          )}
          <Chip label="Date">
            <CalendarDays className="text-label-2 size-4 shrink-0" />
            <span className="truncate">{formatDayLabel(date, today)}</span>
            <input
              type="date"
              aria-label="Date"
              value={date}
              max={addDays(today, 366)}
              onChange={(e) => e.target.value && setDate(e.target.value)}
              className="absolute inset-0 opacity-0"
            />
          </Chip>
          {date === today && (
            <button
              type="button"
              onClick={() => setDate(addDays(today, -1))}
              className="press bg-surface text-tint h-9 shrink-0 rounded-full px-3 text-[15px]"
            >
              Yesterday
            </button>
          )}
        </div>
        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          onFocus={() => setNoteFocused(true)}
          onBlur={() => setNoteFocused(false)}
          onKeyDown={(e) => e.key === 'Enter' && (e.currentTarget.blur(), void save())}
          placeholder="Add a note (e.g. Kopi Kenangan)"
          enterKeyHint="done"
          maxLength={120}
          className="bg-surface placeholder:text-label-3 h-10 w-full rounded-[10px] px-3 text-[16px] outline-none"
        />
      </div>

      {/* Keypad + Save */}
      <div className={cn('shrink-0 px-2 pt-2 pb-[max(env(safe-area-inset-bottom),10px)]', noteFocused && 'max-md:hidden')}>
        <Keypad onKey={onKey} />
        <Button block className="mt-2" onClick={save} aria-disabled={!!problem}>
          {problem && amount > 0 ? problem : 'Save'}
        </Button>
      </div>
    </div>
  )
}

function accountName(accounts: Account[], id: string) {
  const a = accounts.find((x) => x.id === id)
  return a ? `${a.icon} ${a.name}` : 'No account'
}

function Chip({ children, label }: { children: ReactNode; label: string }) {
  return (
    <label className="press bg-surface relative flex h-9 min-w-0 items-center gap-1.5 rounded-full px-3 text-[15px]" aria-label={label}>
      {children}
    </label>
  )
}

function TransferPicker({
  accounts,
  from,
  to,
  onFrom,
  onTo,
}: {
  accounts: Account[]
  from: string
  to: string
  onFrom: (id: string) => void
  onTo: (id: string) => void
}) {
  const Card = ({ label, value, onChange }: { label: string; value: string; onChange: (id: string) => void }) => {
    const a = accounts.find((x) => x.id === value)
    return (
      <label className="bg-surface press relative flex items-center gap-3 rounded-[14px] p-3">
        {a ? <IconBadge icon={a.icon} color={a.color} /> : <span className="bg-fill size-9 rounded-[10px]" />}
        <span className="min-w-0 flex-1">
          <span className="text-label-2 block text-[13px]">{label}</span>
          <span className="block truncate text-[17px] font-medium">{a?.name ?? 'Choose account'}</span>
        </span>
        <ChevronDown className="text-label-2 size-5" />
        <select aria-label={label} value={value} onChange={(e) => onChange(e.target.value)} className="absolute inset-0 opacity-0">
          <option value="" disabled>
            Choose account
          </option>
          {accounts.map((x) => (
            <option key={x.id} value={x.id}>
              {x.icon} {x.name}
            </option>
          ))}
        </select>
      </label>
    )
  }
  return (
    <div className="relative space-y-2 pt-1">
      <Card label="From" value={from} onChange={onFrom} />
      <button
        type="button"
        aria-label="Swap accounts"
        onClick={() => {
          onFrom(to)
          onTo(from)
        }}
        className="press bg-elevated text-tint border-bg absolute top-1/2 right-10 z-10 flex size-9 -translate-y-1/2 items-center justify-center rounded-full border-4"
      >
        <ArrowDownUp className="size-4" strokeWidth={2.4} />
      </button>
      <Card label="To" value={to} onChange={onTo} />
      {accounts.length < 2 && (
        <p className="text-label-2 px-1 pt-1 text-[13px]">You need at least two accounts to make a transfer. Add one in More → Accounts.</p>
      )}
    </div>
  )
}
