import { useState } from 'react'
import { db } from '@/db/db'
import { remove, upsert } from '@/db/repo'
import type { Category, CategoryKind, ColorName } from '@/db/types'
import { budgetId } from '@/domain/budgets'
import { useLedger } from '@/hooks/useLedger'
import { PlainInputRow } from '@/components/ui/Fields'
import { ListGroup } from '@/components/ui/List'
import { Sheet, SheetButton } from '@/components/ui/Sheet'
import { AppearancePicker, CATEGORY_EMOJI } from '@/components/ui/AppearancePicker'
import { useToast } from '@/components/ui/Toast'
import { useConfirm } from '@/components/ui/Confirm'

export function CategorySheet({
  open,
  onClose,
  category,
  kind,
}: {
  open: boolean
  onClose: () => void
  category?: Category
  kind: CategoryKind
}) {
  const { categories, transactions } = useLedger()
  const toast = useToast()
  const confirm = useConfirm()
  const [name, setName] = useState(category?.name ?? '')
  const [icon, setIcon] = useState(category?.icon ?? (kind === 'income' ? '💰' : '📦'))
  const [color, setColor] = useState<ColorName>(category?.color ?? 'blue')

  const save = async () => {
    if (!name.trim()) return
    await upsert('categories', {
      id: category?.id,
      name: name.trim(),
      kind: category?.kind ?? kind,
      icon,
      color,
      order: category?.order ?? Math.max(0, ...categories.map((c) => c.order)) + 1,
    })
    toast({ message: category ? 'Category updated' : 'Category added' })
    onClose()
  }

  const del = async () => {
    if (!category) return
    const used = transactions.filter((t) => t.categoryId === category.id).length
    const ok = await confirm({
      title: `Delete “${category.name}”?`,
      message: used ? `${used} transaction${used === 1 ? '' : 's'} will show as Uncategorized. Its budget is removed too.` : undefined,
      confirmLabel: 'Delete category',
      destructive: true,
    })
    if (!ok) return
    await db.transaction('rw', db.categories, db.budgets, async () => {
      await remove('budgets', [budgetId(category.id)])
      await remove('categories', [category.id])
    })
    toast({ message: 'Category deleted' })
    onClose()
  }

  return (
    <Sheet
      open={open}
      onClose={onClose}
      title={category ? 'Edit category' : `New ${kind} category`}
      leading={<SheetButton onClick={onClose}>Cancel</SheetButton>}
      trailing={
        <SheetButton bold onClick={save} disabled={!name.trim()}>
          Save
        </SheetButton>
      }
    >
      <div className="overflow-y-auto pt-2 pb-[max(env(safe-area-inset-bottom),24px)]">
        <ListGroup>
          <PlainInputRow value={name} onChange={(e) => setName(e.target.value)} placeholder="Name" maxLength={30} aria-label="Category name" autoFocus={!category} />
        </ListGroup>
        <ListGroup header="Appearance">
          <AppearancePicker icon={icon} color={color} onIcon={setIcon} onColor={setColor} presets={CATEGORY_EMOJI} />
        </ListGroup>
        {category && (
          <ListGroup>
            <button type="button" onClick={del} className="row-press text-negative h-11 w-full text-[17px]">
              Delete category
            </button>
          </ListGroup>
        )}
      </div>
    </Sheet>
  )
}
