import { useState } from 'react'
import { remove, upsert } from '@/db/repo'
import type { Budget } from '@/db/types'
import { budgetId } from '@/domain/budgets'
import { useLedger } from '@/hooks/useLedger'
import { formatRp } from '@/lib/money'
import { AmountInput, FieldRow, SelectRow } from '@/components/ui/Fields'
import { ListGroup } from '@/components/ui/List'
import { Sheet, SheetButton } from '@/components/ui/Sheet'
import { useToast } from '@/components/ui/Toast'

const OVERALL = '__overall__'

export function BudgetSheet({
  open,
  onClose,
  budget,
  initialCategoryId,
  suggested,
}: {
  open: boolean
  onClose: () => void
  budget?: Budget
  initialCategoryId?: string | null
  /** Average monthly spend for the category, shown as a hint */
  suggested?: (categoryId: string | null) => number
}) {
  const { categories, budgets } = useLedger()
  const toast = useToast()
  const [cat, setCat] = useState<string>(budget ? (budget.categoryId ?? OVERALL) : initialCategoryId === undefined ? OVERALL : (initialCategoryId ?? OVERALL))
  const [amount, setAmount] = useState(budget?.amount ?? 0)

  const taken = new Set(budgets.filter((b) => b.id !== budget?.id).map((b) => b.categoryId ?? OVERALL))
  const options = [
    { value: OVERALL, label: 'Overall (all spending)' },
    ...categories.filter((c) => c.kind === 'expense').map((c) => ({ value: c.id, label: `${c.icon} ${c.name}` })),
  ].filter((o) => !taken.has(o.value) || o.value === cat)

  const categoryId = cat === OVERALL ? null : cat
  const hint = suggested?.(categoryId) ?? 0

  const save = async () => {
    if (amount <= 0) return
    if (budget && budget.categoryId !== categoryId) await remove('budgets', [budget.id])
    await upsert('budgets', { id: budgetId(categoryId), categoryId, amount })
    toast({ message: 'Budget saved' })
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      size="auto"
      title={budget ? 'Edit budget' : 'New budget'}
      leading={<SheetButton onClick={onClose}>Cancel</SheetButton>}
      trailing={
        <SheetButton bold onClick={save} disabled={amount <= 0}>
          Save
        </SheetButton>
      }
    >
      <div className="overflow-y-auto pt-4 pb-[max(env(safe-area-inset-bottom),16px)]">
        <ListGroup
          footer={
            hint > 0
              ? `You've spent about ${formatRp(hint)} a month here recently.`
              : 'Budgets reset every month. You’ll see a warning at 80%.'
          }
        >
          <SelectRow label="Category" value={cat} onChange={setCat} options={options} />
          <FieldRow label="Monthly limit" htmlFor="budget-amount">
            <AmountInput id="budget-amount" value={amount} onChange={setAmount} autoFocus />
          </FieldRow>
        </ListGroup>
        {hint > 0 && amount === 0 && (
          <div className="mx-8 -mt-5 mb-4">
            <button type="button" onClick={() => setAmount(Math.ceil(hint / 50_000) * 50_000)} className="text-tint text-[15px] font-medium">
              Use {formatRp(Math.ceil(hint / 50_000) * 50_000)}
            </button>
          </div>
        )}
        {budget && (
          <ListGroup>
            <button
              type="button"
              onClick={async () => {
                await remove('budgets', [budget.id])
                toast({ message: 'Budget removed' })
                onClose()
              }}
              className="row-press text-negative h-11 w-full text-[17px]"
            >
              Remove budget
            </button>
          </ListGroup>
        )}
      </div>
    </Sheet>
  )
}
