import { db } from '@/db/db'
import { nextStamp, notifyLocalChange, patch, upsert } from '@/db/repo'
import type { RecurringRule, Transaction } from '@/db/types'
import { todayISO, type ISODate } from '@/lib/dates'
import { dueOccurrences, recurringTxId } from './recurring'

function txFromRule(rule: RecurringRule, date: ISODate): Transaction {
  const now = Date.now()
  return {
    id: recurringTxId(rule.id, date),
    type: rule.type,
    amount: rule.amount,
    accountId: rule.accountId,
    toAccountId: rule.type === 'transfer' ? rule.toAccountId : null,
    categoryId: rule.type === 'transfer' ? null : rule.categoryId,
    date,
    note: rule.note,
    recurringId: rule.id,
    createdAt: now,
    updatedAt: now,
    deleted: 0,
    dirty: 1,
  }
}

/**
 * Logs every due occurrence of auto-post rules. Occurrence ids are
 * deterministic, so if another device already posted (or the user deleted
 * that occurrence on purpose) we never create a duplicate.
 */
export async function postDueRecurring(today: ISODate = todayISO()): Promise<number> {
  const rules = (await db.recurring.toArray()).filter((r) => !r.deleted && r.active && r.autoPost)
  let posted = 0
  let touched = false
  for (const rule of rules) {
    const dates = dueOccurrences(rule, today, 366)
    if (!dates.length) continue
    touched = true
    await db.transaction('rw', db.transactions, db.recurring, async () => {
      for (const date of dates) {
        const id = recurringTxId(rule.id, date)
        if (await db.transactions.get(id)) continue
        await db.transactions.put(txFromRule(rule, date))
        posted++
      }
      const current = await db.recurring.get(rule.id)
      if (current) {
        await db.recurring.put({ ...current, lastPostedDate: dates[dates.length - 1], updatedAt: nextStamp(current), dirty: 1 })
      }
    })
  }
  if (touched) notifyLocalChange()
  return posted
}

/** Remind-mode: confirm an occurrence was paid → log it. */
export async function markOccurrencePaid(rule: RecurringRule, date: ISODate): Promise<void> {
  const tx = txFromRule(rule, date)
  const { id, createdAt: _c, updatedAt: _u, deleted: _d, dirty: _y, ...draft } = tx
  await upsert('transactions', { ...draft, id })
  await patch('recurring', rule.id, { lastPostedDate: maxDate(rule.lastPostedDate, date) })
}

export async function skipOccurrence(rule: RecurringRule, date: ISODate): Promise<void> {
  await patch('recurring', rule.id, { lastPostedDate: maxDate(rule.lastPostedDate, date) })
}

function maxDate(a: ISODate | null, b: ISODate): ISODate {
  return a && a > b ? a : b
}
