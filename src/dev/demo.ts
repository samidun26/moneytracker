/**
 * DEV ONLY — realistic demo data for screenshots and manual testing.
 * Exposed as window.__duitDemo in `npm run dev`; never included in production builds.
 */
import { db } from '@/db/db'
import { ensureSeeded } from '@/db/seed'
import type { Account, Budget, RecurringRule, Transaction, TxType } from '@/db/types'
import { addDays, todayISO } from '@/lib/dates'
import { writeString } from '@/lib/storage'

function rng(seed: number) {
  return () => {
    seed = (seed * 1664525 + 1013904223) % 4294967296
    return seed / 4294967296
  }
}

export async function seedDemo(today = todayISO()): Promise<void> {
  await Promise.all(db.tables.map((t) => t.clear()))
  await ensureSeeded()
  const rand = rng(42)
  const pick = <T,>(a: T[]) => a[Math.floor(rand() * a.length)]
  const between = (lo: number, hi: number, step = 1000) => Math.round((lo + rand() * (hi - lo)) / step) * step
  const now = Date.now()
  const meta = (id: string) => ({ id, createdAt: now, updatedAt: now, deleted: 0 as const, dirty: 1 as const })

  const accounts: Account[] = [
    { ...meta('a-cash'), name: 'Cash', type: 'cash', icon: '💵', color: 'green', openingBalance: 850_000, archived: false, order: 0 },
    { ...meta('a-bca'), name: 'BCA', type: 'bank', icon: '🏦', color: 'blue', openingBalance: 21_400_000, archived: false, order: 1 },
    { ...meta('a-gopay'), name: 'GoPay', type: 'ewallet', icon: '📱', color: 'teal', openingBalance: 320_000, archived: false, order: 2 },
    { ...meta('a-cc'), name: 'Visa Card', type: 'credit', icon: '💳', color: 'purple', openingBalance: -1_850_000, archived: false, order: 3 },
  ]
  await db.accounts.bulkPut(accounts)

  const txs: Transaction[] = []
  let n = 0
  const add = (date: string, type: TxType, amount: number, categoryId: string | null, accountId: string, note: string, toAccountId: string | null = null, recurringId: string | null = null) =>
    txs.push({ ...meta(`d-${n++}`), createdAt: now - n * 1000, type, amount, categoryId, accountId, toAccountId, date, note, recurringId })

  const start = addDays(today, -95)
  for (let d = start; d <= today; d = addDays(d, 1)) {
    const day = Number(d.slice(8))
    const dow = new Date(d).getDay()
    // Food, most days 1–3 times
    for (let i = 0, k = 1 + Math.floor(rand() * 2.4); i < k; i++)
      add(d, 'expense', between(15_000, 68_000), 'c-food', pick(['a-gopay', 'a-cash', 'a-gopay', 'a-bca']), pick(['Nasi Padang', 'Mie Ayam', 'GrabFood', 'Warteg', 'Bakso', 'Sate Ayam', 'Gado-gado', 'Soto Betawi', 'ShopeeFood']))
    if (rand() < 0.55) add(d, 'expense', between(18_000, 52_000), 'c-coffee', pick(['a-gopay', 'a-bca']), pick(['Kopi Kenangan', 'Fore Coffee', 'Starbucks', 'Janji Jiwa', 'Tomoro Coffee']))
    if (rand() < 0.6) add(d, 'expense', between(12_000, 46_000), 'c-transport', 'a-gopay', pick(['Gojek', 'Grab', 'GoCar', 'KRL + MRT']))
    if (dow === 6) add(d, 'expense', between(240_000, 680_000, 500), 'c-groceries', pick(['a-bca', 'a-cc']), pick(['Superindo', 'Hypermart', 'Ranch Market']))
    if (rand() < 0.18) add(d, 'expense', between(25_000, 120_000, 500), 'c-groceries', 'a-gopay', pick(['Indomaret', 'Alfamart']))
    if (day === 2 || day === 16) add(d, 'transfer', 1_000_000, null, 'a-bca', 'ATM withdrawal', 'a-cash')
    if (dow === 0 && rand() < 0.7) add(d, 'expense', between(150_000, 260_000), 'c-transport', 'a-bca', 'Pertamax')
    if (rand() < 0.08) add(d, 'expense', between(120_000, 950_000), 'c-shopping', 'a-cc', pick(['Tokopedia', 'Shopee', 'Uniqlo', 'IKEA']))
    if (rand() < 0.06) add(d, 'expense', between(60_000, 220_000), 'c-entertainment', 'a-cc', pick(['CGV', 'XXI', 'Timezone', 'Karaoke']))
    if (rand() < 0.03) add(d, 'expense', between(45_000, 260_000), 'c-health', 'a-cash', pick(['Apotek K24', 'Halodoc']))
    if (day === 1) add(d, 'expense', 3_500_000, 'c-housing', 'a-bca', 'Kos Tebet', null, 'r-kos')
    if (day === 3) add(d, 'expense', 65_000, 'c-subscriptions', 'a-cc', 'Spotify', null, 'r-spotify')
    if (day === 12) add(d, 'expense', 186_000, 'c-subscriptions', 'a-cc', 'Netflix', null, 'r-netflix')
    if (day === 20) add(d, 'expense', 45_000, 'c-subscriptions', 'a-cc', 'iCloud+', null)
    if (day === 5) add(d, 'expense', between(250_000, 380_000), 'c-bills', 'a-bca', 'Token PLN')
    if (day === 7) add(d, 'expense', 385_000, 'c-bills', 'a-bca', 'IndiHome', null, 'r-indihome')
    if (day === 10) add(d, 'expense', 100_000, 'c-bills', 'a-gopay', 'Telkomsel data')
    if (day === 25) add(d, 'income', 16_500_000, 'c-salary', 'a-bca', 'Salary', null, 'r-salary')
    if (day === 8 || day === 15 || day === 22 || day === 28) add(d, 'transfer', 600_000, null, 'a-bca', 'Top up GoPay', 'a-gopay')
    if (day === 26) add(d, 'transfer', 2_000_000, null, 'a-bca', 'Pay credit card', 'a-cc')
    if (day === 18 && rand() < 0.7) add(d, 'income', between(1_500_000, 3_500_000, 50_000), 'c-freelance', 'a-bca', pick(['Landing page project', 'Logo design', 'UI audit']))
    if (day === 14 && rand() < 0.6) add(d, 'expense', between(150_000, 500_000, 50_000), 'c-family', 'a-bca', 'Kiriman ortu')
  }
  // Today's entries so the home screen feels alive
  add(today, 'expense', 32_000, 'c-coffee', 'a-gopay', 'Kopi Kenangan')
  add(today, 'expense', 27_000, 'c-food', 'a-cash', 'Nasi Uduk')
  await db.transactions.bulkPut(txs)

  const budgets: Budget[] = [
    { ...meta('b-total'), categoryId: null, amount: 14_000_000 },
    { ...meta('b-c-food'), categoryId: 'c-food', amount: 2_600_000 },
    { ...meta('b-c-coffee'), categoryId: 'c-coffee', amount: 600_000 },
    { ...meta('b-c-transport'), categoryId: 'c-transport', amount: 1_300_000 },
    { ...meta('b-c-shopping'), categoryId: 'c-shopping', amount: 1_500_000 },
  ]
  await db.budgets.bulkPut(budgets)

  const last = (day: number) => {
    const t = Number(today.slice(8))
    const m = t >= day ? today.slice(0, 7) : addDays(`${today.slice(0, 7)}-01`, -1).slice(0, 7)
    return `${m}-${String(day).padStart(2, '0')}`
  }
  const rule = (id: string, p: Partial<RecurringRule>): RecurringRule => ({
    ...meta(id), type: 'expense', amount: 0, accountId: 'a-bca', toAccountId: null, categoryId: null, note: '',
    frequency: 'monthly', interval: 1, startDate: '2026-01-01', endDate: null, autoPost: true, lastPostedDate: null, active: true, ...p,
  })
  await db.recurring.bulkPut([
    rule('r-salary', { type: 'income', amount: 16_500_000, categoryId: 'c-salary', note: 'Salary', startDate: '2026-01-25', lastPostedDate: last(25) }),
    rule('r-kos', { amount: 3_500_000, categoryId: 'c-housing', note: 'Kos Tebet', startDate: '2026-01-01', autoPost: false, lastPostedDate: last(1) }),
    rule('r-netflix', { amount: 186_000, categoryId: 'c-subscriptions', note: 'Netflix', accountId: 'a-cc', startDate: '2026-01-12', lastPostedDate: last(12) }),
    rule('r-spotify', { amount: 65_000, categoryId: 'c-subscriptions', note: 'Spotify', accountId: 'a-cc', startDate: '2026-01-03', lastPostedDate: last(3) }),
    rule('r-indihome', { amount: 385_000, categoryId: 'c-bills', note: 'IndiHome', startDate: '2026-01-07', lastPostedDate: last(7) }),
    rule('r-bpjs', { amount: 150_000, categoryId: 'c-health', note: 'BPJS Kesehatan', startDate: '2026-01-23', autoPost: false, lastPostedDate: addDays(last(23), -31) }),
  ])
  writeString('duit.onboarded', '1')
}
