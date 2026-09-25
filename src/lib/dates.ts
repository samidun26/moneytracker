/**
 * Dates are stored as local calendar days ("YYYY-MM-DD") — a coffee bought at
 * 23:30 belongs to that day regardless of timezone math. Months are "YYYY-MM".
 */
export type ISODate = string
export type MonthKey = string

const pad = (n: number) => String(n).padStart(2, '0')

export function toISODate(d: Date): ISODate {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function parseISODate(s: ISODate): Date {
  const [y, m, d] = s.split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function todayISO(now: Date = new Date()): ISODate {
  return toISODate(now)
}

export function addDays(s: ISODate, days: number): ISODate {
  const d = parseISODate(s)
  d.setDate(d.getDate() + days)
  return toISODate(d)
}

export function daysInMonth(year: number, month0: number): number {
  return new Date(year, month0 + 1, 0).getDate()
}

/** Add months keeping the day-of-month, clamped to the target month's length. */
export function addMonthsClamped(s: ISODate, months: number, anchorDay?: number): ISODate {
  const [y, m, d] = s.split('-').map(Number)
  const total = y * 12 + (m - 1) + months
  const ny = Math.floor(total / 12)
  const nm = total % 12
  const day = Math.min(anchorDay ?? d, daysInMonth(ny, nm))
  return `${ny}-${pad(nm + 1)}-${pad(day)}`
}

export function monthKey(s: ISODate): MonthKey {
  return s.slice(0, 7)
}

export function currentMonth(now: Date = new Date()): MonthKey {
  return monthKey(todayISO(now))
}

export function shiftMonth(key: MonthKey, delta: number): MonthKey {
  return addMonthsClamped(`${key}-01`, delta).slice(0, 7)
}

export function monthBounds(key: MonthKey): { start: ISODate; end: ISODate; days: number } {
  const [y, m] = key.split('-').map(Number)
  const days = daysInMonth(y, m - 1)
  return { start: `${key}-01`, end: `${key}-${pad(days)}`, days }
}

export function diffDays(a: ISODate, b: ISODate): number {
  const ms = parseISODate(b).getTime() - parseISODate(a).getTime()
  return Math.round(ms / 86_400_000)
}

// Hand-rolled (not Intl) so output is identical in Safari, Chrome and Node.
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
const short = (s: string) => s.slice(0, 3)

export function weekdayName(s: ISODate): string {
  return WEEKDAYS[parseISODate(s).getDay()]
}

/** "September 2026" */
export function formatMonth(key: MonthKey): string {
  return `${MONTHS[Number(key.slice(5, 7)) - 1]} ${key.slice(0, 4)}`
}

/** "Sep" */
export function formatMonthShort(key: MonthKey): string {
  return short(MONTHS[Number(key.slice(5, 7)) - 1])
}

/** "Today", "Yesterday", "Tomorrow", "Wed, 24 Sep" (adds year if not current) */
export function formatDayLabel(s: ISODate, today: ISODate = todayISO()): string {
  const diff = diffDays(today, s)
  if (diff === 0) return 'Today'
  if (diff === -1) return 'Yesterday'
  if (diff === 1) return 'Tomorrow'
  const base = `${short(weekdayName(s))}, ${formatShortDate(s)}`
  return s.slice(0, 4) === today.slice(0, 4) ? base : `${base} ${s.slice(0, 4)}`
}

/** "24 Sep" */
export function formatShortDate(s: ISODate): string {
  return `${Number(s.slice(8, 10))} ${short(MONTHS[Number(s.slice(5, 7)) - 1])}`
}

/** "in 3 days", "today", "2 days ago" */
export function formatRelativeDays(s: ISODate, today: ISODate = todayISO()): string {
  const diff = diffDays(today, s)
  if (diff === 0) return 'today'
  if (diff === 1) return 'tomorrow'
  if (diff === -1) return 'yesterday'
  return diff > 0 ? `in ${diff} days` : `${-diff} days ago`
}

export function ordinal(n: number): string {
  const s = ['th', 'st', 'nd', 'rd']
  const v = n % 100
  return n + (s[(v - 20) % 10] || s[v] || s[0])
}

export function timeAgo(ts: number, now = Date.now()): string {
  const s = Math.max(0, Math.round((now - ts) / 1000))
  if (s < 45) return 'just now'
  const m = Math.round(s / 60)
  if (m < 60) return `${m}m ago`
  const h = Math.round(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.round(h / 24)}d ago`
}

/** For use mid-sentence: "today", "tomorrow", "on Wed, 1 Oct" */
export function formatDayPhrase(s: ISODate, today: ISODate = todayISO()): string {
  const label = formatDayLabel(s, today)
  return ['Today', 'Tomorrow', 'Yesterday'].includes(label) ? label.toLowerCase() : `on ${label}`
}
