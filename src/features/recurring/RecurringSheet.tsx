import { useMemo, useState } from 'react'
import { remove, upsert } from '@/db/repo'
import type { Frequency, RecurringRule, TxType } from '@/db/types'
import { describeSchedule, nextOccurrence } from '@/domain/recurring'
import { useLedger } from '@/hooks/useLedger'
import { addDays, formatDayLabel, formatDayPhrase, todayISO } from '@/lib/dates'
import { AmountInput, DateRow, FieldRow, PlainInputRow, SelectRow, ToggleRow } from '@/components/ui/Fields'
import { ListGroup } from '@/components/ui/List'
import { SegmentedControl } from '@/components/ui/SegmentedControl'
import { Sheet, SheetButton } from '@/components/ui/Sheet'
import { useToast } from '@/components/ui/Toast'
import { useConfirm } from '@/components/ui/Confirm'

const FREQS: Array<{ value: Frequency; label: string }> = [
  { value: 'daily', label: 'Daily' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'monthly', label: 'Monthly' },
  { value: 'yearly', label: 'Yearly' },
]
const UNIT: Record<Frequency, string> = { daily: 'day', weekly: 'week', monthly: 'month', yearly: 'year' }

export function RecurringSheet({ open, onClose, rule }: { open: boolean; onClose: () => void; rule?: RecurringRule }) {
  const { categories, activeAccounts, accounts } = useLedger()
  const toast = useToast()
  const confirm = useConfirm()
  const today = todayISO()

  const [type, setType] = useState<TxType>(rule?.type ?? 'expense')
  const [note, setNote] = useState(rule?.note ?? '')
  const [amount, setAmount] = useState(rule?.amount ?? 0)
  const [categoryId, setCategoryId] = useState(rule?.categoryId ?? '')
  const [accountId, setAccountId] = useState(rule?.accountId ?? activeAccounts[0]?.id ?? '')
  const [toAccountId, setToAccountId] = useState(rule?.toAccountId ?? activeAccounts[1]?.id ?? '')
  const [frequency, setFrequency] = useState<Frequency>(rule?.frequency ?? 'monthly')
  const [interval, setInterval] = useState(rule?.interval ?? 1)
  const [startDate, setStartDate] = useState(rule?.startDate ?? today)
  const [endDate, setEndDate] = useState<string | null>(rule?.endDate ?? null)
  const [autoPost, setAutoPost] = useState(rule?.autoPost ?? true)
  const [active, setActive] = useState(rule?.active ?? true)

  const kindCats = categories.filter((c) => c.kind === (type === 'income' ? 'income' : 'expense'))
  const pickable = accounts.filter((a) => !a.archived || a.id === accountId || a.id === toAccountId)
  const accountOptions = pickable.map((a) => ({ value: a.id, label: `${a.icon} ${a.name}` }))

  const schedule = { frequency, interval, startDate, endDate }
  const next = useMemo(() => nextOccurrence(schedule, addDays(today, -1)), [frequency, interval, startDate, endDate, today]) // eslint-disable-line react-hooks/exhaustive-deps

  const valid =
    amount > 0 &&
    !!accountId &&
    (type === 'transfer' ? !!toAccountId && toAccountId !== accountId : !!categoryId && kindCats.some((c) => c.id === categoryId))

  const save = async () => {
    if (!valid) return
    // Don't back-fill history: a rule that "started" in the past begins logging from today.
    const startChanged = !rule || rule.startDate !== startDate
    const lastPostedDate = startChanged ? (startDate < today ? addDays(today, -1) : null) : rule!.lastPostedDate
    await upsert('recurring', {
      id: rule?.id,
      type,
      note: note.trim(),
      amount,
      accountId,
      toAccountId: type === 'transfer' ? toAccountId : null,
      categoryId: type === 'transfer' ? null : categoryId,
      frequency,
      interval,
      startDate,
      endDate,
      autoPost,
      active,
      lastPostedDate,
    })
    toast({ message: rule ? 'Recurring updated' : 'Recurring added' })
    onClose()
  }

  const del = async () => {
    if (!rule) return
    const ok = await confirm({
      title: `Delete “${rule.note || 'this rule'}”?`,
      message: 'Transactions it already logged stay in your history.',
      confirmLabel: 'Delete recurring',
      destructive: true,
    })
    if (!ok) return
    await remove('recurring', [rule.id])
    toast({ message: 'Recurring deleted' })
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={rule ? 'Edit recurring' : 'New recurring'}
      leading={<SheetButton onClick={onClose}>Cancel</SheetButton>}
      trailing={
        <SheetButton bold onClick={save} disabled={!valid}>
          Save
        </SheetButton>
      }
    >
      <div className="overflow-y-auto pt-2 pb-[max(env(safe-area-inset-bottom),24px)]">
        <div className="mx-4 mb-6">
          <SegmentedControl
            label="Type"
            value={type}
            onChange={(t) => {
              setType(t)
              setCategoryId('')
            }}
            options={[
              { value: 'expense', label: 'Bill / expense' },
              { value: 'income', label: 'Income' },
              { value: 'transfer', label: 'Transfer' },
            ]}
          />
        </div>
        <ListGroup>
          <PlainInputRow
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={type === 'income' ? 'Name (e.g. Salary)' : type === 'transfer' ? 'Name (e.g. Savings)' : 'Name (e.g. Netflix, Kos)'}
            maxLength={60}
            aria-label="Name"
          />
          <FieldRow label="Amount" htmlFor="rec-amount">
            <AmountInput id="rec-amount" value={amount} onChange={setAmount} />
          </FieldRow>
          {type !== 'transfer' && (
            <SelectRow
              label="Category"
              value={categoryId}
              onChange={setCategoryId}
              options={[{ value: '', label: 'Choose…' }, ...kindCats.map((c) => ({ value: c.id, label: `${c.icon} ${c.name}` }))]}
            />
          )}
          <SelectRow label={type === 'transfer' ? 'From' : 'Account'} value={accountId} onChange={setAccountId} options={accountOptions} />
          {type === 'transfer' && <SelectRow label="To" value={toAccountId} onChange={setToAccountId} options={accountOptions} />}
        </ListGroup>

        <ListGroup footer={next ? `${describeSchedule(schedule)} · next ${formatDayPhrase(next, today)}` : 'This schedule has ended.'}>
          <SelectRow label="Repeats" value={frequency} onChange={setFrequency} options={FREQS} />
          <SelectRow
            label="Every"
            value={String(interval)}
            onChange={(v) => setInterval(Number(v))}
            options={Array.from({ length: 12 }, (_, i) => ({
              value: String(i + 1),
              label: i === 0 ? UNIT[frequency] : `${i + 1} ${UNIT[frequency]}s`,
            }))}
          />
          <DateRow label="Starts" value={startDate} onChange={(v) => v && setStartDate(v)} display={formatDayLabel(startDate, today)} />
          <DateRow
            label="Ends"
            optional
            min={startDate}
            value={endDate}
            onChange={setEndDate}
            display={endDate ? formatDayLabel(endDate, today) : 'Never'}
          />
        </ListGroup>

        <ListGroup
          footer={
            autoPost
              ? 'Duit logs it for you on the due date (next time you open the app).'
              : 'You’ll see it as “Due” on Overview and confirm with Paid or Skip. Good for bills that vary.'
          }
        >
          <ToggleRow label="Log automatically" checked={autoPost} onChange={setAutoPost} />
          {rule && <ToggleRow label="Active" subtitle={active ? undefined : 'Paused. Nothing will be logged.'} checked={active} onChange={setActive} />}
        </ListGroup>

        {rule && (
          <ListGroup>
            <button type="button" onClick={del} className="row-press text-negative h-11 w-full text-[17px]">
              Delete recurring
            </button>
          </ListGroup>
        )}
      </div>
    </Sheet>
  )
}
