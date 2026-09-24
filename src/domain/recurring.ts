import type { Frequency, RecurringRule } from '@/db/types'
import {
  addDays,
  addMonthsClamped,
  diffDays,
  formatShortDate,
  ordinal,
  parseISODate,
  weekdayName,
  type ISODate,
} from '@/lib/dates'

type RuleSchedule = Pick<RecurringRule, 'frequency' | 'interval' | 'startDate' | 'endDate'>

const MAX_STEPS = 5000

/** The n-th occurrence (0-based) of a rule. Monthly rules keep the start day, clamped to month length. */
export function occurrenceAt(rule: RuleSchedule, n: number): ISODate {
  const every = Math.max(1, rule.interval)
  const anchor = Number(rule.startDate.slice(8, 10))
  switch (rule.frequency) {
    case 'daily':
      return addDays(rule.startDate, n * every)
    case 'weekly':
      return addDays(rule.startDate, n * 7 * every)
    case 'monthly':
      return addMonthsClamped(rule.startDate, n * every, anchor)
    case 'yearly':
      return addMonthsClamped(rule.startDate, n * 12 * every, anchor)
  }
}

/** A safe lower-bound index for the first occurrence after `date` (skips long histories quickly). */
function indexNear(rule: RuleSchedule, date: ISODate): number {
  const days = diffDays(rule.startDate, date)
  if (days <= 0) return 0
  const every = Math.max(1, rule.interval)
  const approx: Record<Frequency, number> = {
    daily: days / every,
    weekly: days / (7 * every),
    monthly: days / (31 * every),
    yearly: days / (366 * every),
  }
  return Math.max(0, Math.floor(approx[rule.frequency]) - 1)
}

/** Occurrences in (after, until] — `after` exclusive, `until` inclusive — honoring endDate. */
export function occurrencesBetween(rule: RuleSchedule, after: ISODate | null, until: ISODate, limit = 400): ISODate[] {
  const out: ISODate[] = []
  const end = rule.endDate && rule.endDate < until ? rule.endDate : until
  let n = after ? indexNear(rule, after) : 0
  for (let steps = 0; steps < MAX_STEPS && out.length < limit; steps++, n++) {
    const d = occurrenceAt(rule, n)
    if (d > end) break
    if (after && d <= after) continue
    out.push(d)
  }
  return out
}

export function nextOccurrence(rule: RuleSchedule, after: ISODate): ISODate | null {
  return occurrencesBetween(rule, after, '9999-12-31', 1)[0] ?? null
}

/** Occurrences that are due (≤ today) and not yet posted or skipped. */
export function dueOccurrences(rule: RecurringRule, today: ISODate, limit = 400): ISODate[] {
  if (!rule.active) return []
  const after = rule.lastPostedDate ?? addDays(rule.startDate, -1)
  return occurrencesBetween(rule, after, today, limit)
}

/** Next date the rule will fire, after anything already handled. */
export function nextDueDate(rule: RecurringRule): ISODate | null {
  if (!rule.active) return null
  return nextOccurrence(rule, rule.lastPostedDate ?? addDays(rule.startDate, -1))
}

export function recurringTxId(ruleId: string, date: ISODate): string {
  return `r-${ruleId}-${date}`
}

/** Normalized monthly cost, for "fixed costs per month" totals. */
export function monthlyEquivalent(rule: Pick<RecurringRule, 'amount' | 'frequency' | 'interval'>): number {
  const every = Math.max(1, rule.interval)
  const perYear: Record<Frequency, number> = { daily: 365, weekly: 52, monthly: 12, yearly: 1 }
  return Math.round((rule.amount * perYear[rule.frequency]) / every / 12)
}

export function describeSchedule(rule: RuleSchedule): string {
  const every = Math.max(1, rule.interval)
  const start = parseISODate(rule.startDate)
  switch (rule.frequency) {
    case 'daily':
      return every === 1 ? 'Every day' : `Every ${every} days`
    case 'weekly':
      return every === 1 ? `Every ${weekdayName(rule.startDate)}` : `Every ${every} weeks on ${weekdayName(rule.startDate)}`
    case 'monthly': {
      const day = ordinal(start.getDate())
      return every === 1 ? `Monthly on the ${day}` : `Every ${every} months on the ${day}`
    }
    case 'yearly':
      return every === 1 ? `Yearly on ${formatShortDate(rule.startDate)}` : `Every ${every} years on ${formatShortDate(rule.startDate)}`
  }
}

export interface Occurrence {
  rule: RecurringRule
  date: ISODate
  status: 'due' | 'upcoming'
}

/** Due items (remind-mode rules) + upcoming items within the horizon, sorted by date. */
export function upcomingOccurrences(rules: RecurringRule[], today: ISODate, horizonDays: number): Occurrence[] {
  const horizon = addDays(today, horizonDays)
  const out: Occurrence[] = []
  for (const rule of rules) {
    if (!rule.active) continue
    for (const date of dueOccurrences(rule, today, 12)) out.push({ rule, date, status: 'due' })
    for (const date of occurrencesBetween(rule, today, horizon, 12)) out.push({ rule, date, status: 'upcoming' })
  }
  return out.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : b.rule.amount - a.rule.amount))
}
