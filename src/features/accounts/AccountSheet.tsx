import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { db } from '@/db/db'
import { remove, upsert } from '@/db/repo'
import { ACCOUNT_TYPES } from '@/db/seed'
import type { Account, AccountType, ColorName } from '@/db/types'
import { useLedger } from '@/hooks/useLedger'
import { AmountInput, FieldRow, PlainInputRow, SelectRow, ToggleRow } from '@/components/ui/Fields'
import { ListGroup } from '@/components/ui/List'
import { Sheet, SheetButton } from '@/components/ui/Sheet'
import { AppearancePicker, ACCOUNT_EMOJI } from '@/components/ui/AppearancePicker'
import { useToast } from '@/components/ui/Toast'
import { useConfirm } from '@/components/ui/Confirm'

export function AccountSheet({ open, onClose, account }: { open: boolean; onClose: () => void; account?: Account }) {
  const { accounts, transactions, rules } = useLedger()
  const toast = useToast()
  const confirm = useConfirm()
  const navigate = useNavigate()
  const [name, setName] = useState(account?.name ?? '')
  const [type, setType] = useState<AccountType>(account?.type ?? 'bank')
  const [icon, setIcon] = useState(account?.icon ?? '🏦')
  const [color, setColor] = useState<ColorName>(account?.color ?? 'blue')
  const isCredit = type === 'credit'
  // Credit cards: users think in "amount owed" (positive); we store a negative balance.
  const [opening, setOpening] = useState(account ? (account.type === 'credit' ? -account.openingBalance : account.openingBalance) : 0)
  const [archived, setArchived] = useState(account?.archived ?? false)

  const changeType = (t: AccountType) => {
    const preset = ACCOUNT_TYPES.find((p) => p.type === t)!
    if (!account && ACCOUNT_TYPES.some((p) => p.icon === icon)) {
      setIcon(preset.icon)
      setColor(preset.color)
    }
    if ((t === 'credit') !== isCredit) setOpening(-opening)
    setType(t)
  }

  const save = async () => {
    if (!name.trim()) return
    await upsert('accounts', {
      id: account?.id,
      name: name.trim(),
      type,
      icon,
      color,
      openingBalance: isCredit ? -Math.abs(opening) : opening,
      archived,
      order: account?.order ?? accounts.length,
    })
    toast({ message: account ? 'Account updated' : 'Account added' })
    onClose()
  }

  const del = async () => {
    if (!account) return
    const txIds = transactions.filter((t) => t.accountId === account.id || t.toAccountId === account.id).map((t) => t.id)
    const ruleIds = rules.filter((r) => r.accountId === account.id || r.toAccountId === account.id).map((r) => r.id)
    const ok = await confirm({
      title: `Delete ${account.name}?`,
      message: txIds.length
        ? `This also deletes its ${txIds.length} transaction${txIds.length === 1 ? '' : 's'}. To keep history, archive it instead.`
        : 'This cannot be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    })
    if (!ok) return
    await db.transaction('rw', db.accounts, db.transactions, db.recurring, async () => {
      await remove('transactions', txIds)
      await remove('recurring', ruleIds)
      await remove('accounts', [account.id])
    })
    toast({ message: `${account.name} deleted` })
    onClose()
    navigate('/accounts', { replace: true })
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={account ? 'Edit account' : 'New account'}
      leading={<SheetButton onClick={onClose}>Cancel</SheetButton>}
      trailing={
        <SheetButton bold onClick={save} disabled={!name.trim()}>
          Save
        </SheetButton>
      }
    >
      <div className="overflow-y-auto pt-2 pb-[max(env(safe-area-inset-bottom),24px)]">
        <ListGroup>
          <PlainInputRow value={name} onChange={(e) => setName(e.target.value)} placeholder="Name (e.g. BCA, GoPay, Cash)" maxLength={40} aria-label="Account name" autoFocus={!account} />
          <SelectRow label="Type" value={type} onChange={changeType} options={ACCOUNT_TYPES.map((t) => ({ value: t.type, label: t.label }))} />
          <FieldRow label={isCredit ? (account ? 'Owed at start' : 'Amount owed now') : account ? 'Opening balance' : 'Current balance'} htmlFor="acc-opening">
            <AmountInput id="acc-opening" value={opening} onChange={setOpening} allowNegative={!isCredit} />
          </FieldRow>
        </ListGroup>
        <ListGroup header="Appearance">
          <AppearancePicker icon={icon} color={color} onIcon={setIcon} onColor={setColor} presets={ACCOUNT_EMOJI} />
        </ListGroup>
        {account && (
          <>
            <ListGroup footer="Archived accounts are hidden from pickers and net worth, but their history stays.">
              <ToggleRow label="Archived" checked={archived} onChange={setArchived} />
            </ListGroup>
            <ListGroup>
              <button type="button" onClick={del} className="row-press text-negative h-11 w-full text-[17px]">
                Delete account
              </button>
            </ListGroup>
          </>
        )}
      </div>
    </Sheet>
  )
}
