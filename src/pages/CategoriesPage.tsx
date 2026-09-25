import { useState } from 'react'
import { ArrowDown, ArrowUp, Plus } from 'lucide-react'
import { patch } from '@/db/repo'
import type { Category, CategoryKind } from '@/db/types'
import { useLedger } from '@/hooks/useLedger'
import { Page, NavButton } from '@/components/ui/Page'
import { ListGroup, ListRow } from '@/components/ui/List'
import { IconBadge } from '@/components/ui/IconBadge'
import { SegmentedControl } from '@/components/ui/SegmentedControl'
import { CategorySheet } from '@/features/categories/CategorySheet'

export function CategoriesPage() {
  const { categories, transactions } = useLedger()
  const [kind, setKind] = useState<CategoryKind>('expense')
  const [reorder, setReorder] = useState(false)
  const [sheet, setSheet] = useState<{ open: boolean; category?: Category; key: number }>({ open: false, key: 0 })
  const open = (category?: Category) => setSheet((s) => ({ open: true, category, key: s.key + 1 }))

  const list = categories.filter((c) => c.kind === kind)
  const usage = new Map<string, number>()
  for (const t of transactions) if (t.categoryId) usage.set(t.categoryId, (usage.get(t.categoryId) ?? 0) + 1)

  /** Swap with neighbor, then renumber so orders stay dense. */
  const move = async (i: number, dir: -1 | 1) => {
    const j = i + dir
    if (j < 0 || j >= list.length) return
    const next = [...list]
    ;[next[i], next[j]] = [next[j], next[i]]
    await Promise.all(next.map((c, k) => (c.order !== k ? patch('categories', c.id, { order: k }) : null)))
  }

  return (
    <Page
      title="Categories"
      back={{ label: 'More', to: '/more' }}
      actions={
        <>
          <NavButton label={reorder ? 'Done reordering' : 'Reorder'} bold={reorder} onClick={() => setReorder((r) => !r)}>
            {reorder ? 'Done' : 'Reorder'}
          </NavButton>
          {!reorder && (
            <NavButton label="Add category" onClick={() => open()}>
              <Plus className="size-6" strokeWidth={2.4} />
            </NavButton>
          )}
        </>
      }
      subheader={
        <SegmentedControl
          label="Kind"
          value={kind}
          onChange={setKind}
          options={[
            { value: 'expense', label: 'Expense' },
            { value: 'income', label: 'Income' },
          ]}
        />
      }
    >
      <ListGroup footer={reorder ? 'This order is used in the add-transaction grid.' : 'Tap a category to rename it or change its icon.'}>
        {list.map((c, i) => (
          <ListRow
            key={c.id}
            leading={<IconBadge icon={c.icon} color={c.color} />}
            title={c.name}
            subtitle={usage.get(c.id) ? `${usage.get(c.id)} transactions` : undefined}
            onClick={reorder ? undefined : () => open(c)}
            chevron={!reorder}
            trailing={
              reorder ? (
                <span className="flex gap-1">
                  <button type="button" aria-label={`Move ${c.name} up`} disabled={i === 0} onClick={() => move(i, -1)} className="press bg-fill text-tint flex size-8 items-center justify-center rounded-full disabled:opacity-30">
                    <ArrowUp className="size-4" strokeWidth={2.6} />
                  </button>
                  <button type="button" aria-label={`Move ${c.name} down`} disabled={i === list.length - 1} onClick={() => move(i, 1)} className="press bg-fill text-tint flex size-8 items-center justify-center rounded-full disabled:opacity-30">
                    <ArrowDown className="size-4" strokeWidth={2.6} />
                  </button>
                </span>
              ) : undefined
            }
          />
        ))}
      </ListGroup>
      <CategorySheet key={sheet.key} open={sheet.open} category={sheet.category} kind={kind} onClose={() => setSheet((s) => ({ ...s, open: false }))} />
    </Page>
  )
}
